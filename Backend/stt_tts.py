import os
import json
import yaml
from typing import Optional, Dict, Any
import pyttsx3
import requests

class STTEngine:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.engine_type = config.get('engine', 'vosk')
        self.model = None
        
        if self.engine_type == 'vosk':
            try:
                import vosk
                model_path = config.get('vosk_model_path', '')
                if model_path and os.path.exists(model_path):
                    self.model = vosk.Model(model_path)
            except ImportError:
                print("Vosk not available, falling back to cloud")
                self.engine_type = 'cloud'
    
    def transcribe(self, audio_data: bytes) -> str:
        if self.engine_type == 'vosk' and self.model:
            return self._transcribe_vosk(audio_data)
        else:
            return self._transcribe_cloud(audio_data)
    
    def _transcribe_vosk(self, audio_data: bytes) -> str:
        try:
            import vosk
            import wave
            import tempfile
            
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                tmp.write(audio_data)
                tmp_path = tmp.name
            
            wf = wave.open(tmp_path, 'rb')
            rec = vosk.KaldiRecognizer(self.model, wf.getframerate())
            rec.SetWords(True)
            
            text = ""
            while True:
                data = wf.readframes(4000)
                if len(data) == 0:
                    break
                if rec.AcceptWaveform(data):
                    result = json.loads(rec.Result())
                    text += result.get('text', '') + ' '
            
            final_result = json.loads(rec.FinalResult())
            text += final_result.get('text', '')
            
            os.unlink(tmp_path)
            return text.strip()
        except Exception as e:
            print(f"Vosk transcription error: {e}")
            return ""
    
    def _transcribe_cloud(self, audio_data: bytes) -> str:
        api_key = self.config.get('cloud_api_key', '')
        endpoint = self.config.get('cloud_endpoint', '')
        
        if not api_key or not endpoint:
            return ""
        
        try:
            files = {'audio': audio_data}
            headers = {'Authorization': f'Bearer {api_key}'}
            response = requests.post(endpoint, files=files, headers=headers, timeout=5)
            if response.status_code == 200:
                return response.json().get('text', '')
        except Exception as e:
            print(f"Cloud STT error: {e}")
        
        return ""

class TTSEngine:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.engine_type = config.get('engine', 'pyttsx3')
        self.engine = None
        
        if self.engine_type == 'pyttsx3':
            try:
                self.engine = pyttsx3.init()
                self.engine.setProperty('rate', config.get('voice_rate', 150))
                voices = self.engine.getProperty('voices')
                for voice in voices:
                    if 'arabic' in voice.name.lower() or 'ar' in voice.id.lower():
                        self.engine.setProperty('voice', voice.id)
                        break
            except Exception as e:
                print(f"TTS initialization error: {e}")
    
    def synthesize(self, text: str, output_path: Optional[str] = None) -> bytes:
        if self.engine_type == 'pyttsx3' and self.engine:
            return self._synthesize_pyttsx3(text, output_path)
        else:
            return self._synthesize_cloud(text, output_path)
    
    def _synthesize_pyttsx3(self, text: str, output_path: Optional[str] = None) -> bytes:
        try:
            if output_path:
                self.engine.save_to_file(text, output_path)
                self.engine.runAndWait()
                with open(output_path, 'rb') as f:
                    return f.read()
            else:
                import tempfile
                with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                    tmp_path = tmp.name
                self.engine.save_to_file(text, tmp_path)
                self.engine.runAndWait()
                with open(tmp_path, 'rb') as f:
                    data = f.read()
                os.unlink(tmp_path)
                return data
        except Exception as e:
            print(f"pyttsx3 synthesis error: {e}")
            return b""
    
    def _synthesize_cloud(self, text: str, output_path: Optional[str] = None) -> bytes:
        api_key = self.config.get('cloud_api_key', '')
        endpoint = self.config.get('cloud_endpoint', '')
        
        if not api_key or not endpoint:
            return b""
        
        try:
            headers = {'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'}
            data = {'text': text, 'language': 'ar'}
            response = requests.post(endpoint, json=data, headers=headers, timeout=10)
            if response.status_code == 200:
                audio_data = response.content
                if output_path:
                    with open(output_path, 'wb') as f:
                        f.write(audio_data)
                return audio_data
        except Exception as e:
            print(f"Cloud TTS error: {e}")
        
        return b""

def load_config(config_path: str = 'config.yaml') -> Dict[str, Any]:
    import os
    if not os.path.isabs(config_path):
        config_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), config_path)
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def get_stt_engine(config: Optional[Dict[str, Any]] = None) -> STTEngine:
    if config is None:
        config = load_config()
    return STTEngine(config.get('stt', {}))

def get_tts_engine(config: Optional[Dict[str, Any]] = None) -> TTSEngine:
    if config is None:
        config = load_config()
    return TTSEngine(config.get('tts', {}))

