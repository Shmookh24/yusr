import json
import re
import os
import pickle
import numpy as np
import pandas as pd
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from collections import Counter, defaultdict
import warnings
warnings.filterwarnings('ignore')

from sklearn.feature_extraction.text import TfidfVectorizer, CountVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.linear_model import SGDClassifier, LogisticRegression
from sklearn.ensemble import RandomForestClassifier, VotingClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.pipeline import Pipeline
from sklearn.model_selection import (
    train_test_split, 
    cross_val_score, 
    StratifiedKFold,
    GridSearchCV,
    RandomizedSearchCV
)
from sklearn.metrics import (
    classification_report, 
    confusion_matrix, 
    accuracy_score,
    precision_recall_fscore_support,
    roc_auc_score,
    f1_score,
    cohen_kappa_score,
    matthews_corrcoef
)
from sklearn.preprocessing import LabelEncoder
import joblib

try:
    import torch
    import torch.nn as nn
    # Check PyTorch version
    torch_version = torch.__version__.split('.')
    major, minor = int(torch_version[0]), int(torch_version[1])
    if major < 2 or (major == 2 and minor < 2):
        raise ImportError(f"PyTorch >= 2.2 required, found {torch.__version__}")
    
    from transformers import (
        AutoTokenizer, 
        AutoModelForSequenceClassification,
        AutoModel,
        TrainingArguments,
        Trainer,
        EarlyStoppingCallback
    )
    from datasets import Dataset
    TRANSFORMERS_AVAILABLE = True
except (ImportError, NameError, AttributeError, RuntimeError, OSError) as e:
    TRANSFORMERS_AVAILABLE = False
    error_msg = str(e)
    if "DLL" in error_msg or "dynamic link library" in error_msg.lower():
        print("Warning: PyTorch installation issue detected. Using sklearn models only.")
        print("To fix: Reinstall PyTorch or use Ensemble Model (recommended)")
    else:
        print(f"Warning: Transformers not available ({error_msg}), will use sklearn models only")

class AdvancedTextPreprocessor:
    def __init__(self):
        self.normalization_map = {
            'أ': 'ا', 'إ': 'ا', 'آ': 'ا',
            'ى': 'ي', 'ة': 'ه',
            'ُ': '', 'ِ': '', 'ً': '', 'ٍ': '', 'ٌ': '', 'ْ': '', 'ّ': ''
        }
    
    def normalize_arabic(self, text: str) -> str:
        for old, new in self.normalization_map.items():
            text = text.replace(old, new)
        return text
    
    def preprocess(self, text: str, normalize: bool = True) -> str:
        text = text.strip().lower()
        if normalize:
            text = self.normalize_arabic(text)
        text = re.sub(r'[^\u0600-\u06FF\s\d]', '', text)
        text = re.sub(r'\s+', ' ', text)
        return text
    
    def augment_text(self, text: str) -> List[str]:
        variations = [text]
        words = text.split()
        
        if len(words) > 1:
            variations.append(' '.join(words[::-1]))
        
        if 'أريد' in text:
            variations.append(text.replace('أريد', 'أبي'))
            variations.append(text.replace('أريد', 'عايز'))
            variations.append(text.replace('أريد', 'أبغى'))
        
        return list(set(variations))

class ArabicNLUModel:
    def __init__(self, use_transformer: bool = False, model_name: str = 'aubmindlab/bert-base-arabertv2'):
        self.use_transformer = use_transformer and TRANSFORMERS_AVAILABLE
        self.model_name = model_name
        self.model = None
        self.vectorizer = None
        self.tokenizer = None
        self.intent_labels = []
        self.label_encoder = LabelEncoder()
        self.preprocessor = AdvancedTextPreprocessor()
        
        self.model_path = os.path.join(os.path.dirname(__file__), 'data', 'nlu_model.pkl')
        self.metadata_path = os.path.join(os.path.dirname(__file__), 'data', 'model_metadata.json')
        self.training_log_path = os.path.join(os.path.dirname(__file__), 'data', 'training_log.json')
        
        self.training_history = []
        
    def load_dataset(self, dataset_path: str, augment: bool = True):
        with open(dataset_path, 'r', encoding='utf-8') as f:
            dataset = json.load(f)
        
        if augment:
            augmented_dataset = []
            for example in dataset:
                augmented_dataset.append(example)
                variations = self.preprocessor.augment_text(example['text'])
                for var_text in variations:
                    if var_text != example['text']:
                        augmented_dataset.append({
                            'intent': example['intent'],
                            'text': var_text,
                            'entities': example.get('entities', {})
                        })
            dataset = augmented_dataset
        
        return dataset
    
    def train_sklearn_ensemble(self, texts: List[str], intents: List[str]):
        print('\nTraining advanced Ensemble Model...')
        
        unique_intents = sorted(list(set(intents)))
        self.intent_labels = unique_intents
        y_encoded = self.label_encoder.fit_transform(intents)
        
        X_train, X_test, y_train, y_test = train_test_split(
            texts, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded
        )
        
        print(f'Data split: {len(X_train)} training, {len(X_test)} testing')
        
        self.vectorizer = TfidfVectorizer(
            analyzer='char_wb',
            ngram_range=(1, 4),
            max_features=10000,
            min_df=2,
            max_df=0.9,
            sublinear_tf=True,
            use_idf=True
        )
        
        print('Converting texts to vectors...')
        X_train_vectors = self.vectorizer.fit_transform(X_train)
        X_test_vectors = self.vectorizer.transform(X_test)
        
        print(f'Vector dimensions: {X_train_vectors.shape}')
        
        models = {
            'svm': SVC(
                kernel='rbf',
                C=1.0,
                gamma='scale',
                probability=True,
                random_state=42
            ),
            'sgd': SGDClassifier(
                loss='log_loss',
                penalty='l2',
                alpha=0.0001,
                max_iter=2000,
                random_state=42,
                learning_rate='optimal',
                early_stopping=True,
                n_iter_no_change=10
            ),
            'rf': RandomForestClassifier(
                n_estimators=200,
                max_depth=20,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42,
                n_jobs=-1
            ),
            'gb': GradientBoostingClassifier(
                n_estimators=100,
                learning_rate=0.1,
                max_depth=5,
                random_state=42
            )
        }
        
        print('\nTraining individual models...')
        trained_models = {}
        for name, model in models.items():
            print(f'  Training {name}...')
            model.fit(X_train_vectors, y_train)
            y_pred = model.predict(X_test_vectors)
            acc = accuracy_score(y_test, y_pred)
            f1 = f1_score(y_test, y_pred, average='weighted')
            print(f'  {name}: Accuracy={acc:.4f}, F1={f1:.4f}')
            trained_models[name] = model
        
        print('\nCreating Ensemble Model...')
        self.model = VotingClassifier(
            estimators=[
                ('svm', trained_models['svm']),
                ('sgd', trained_models['sgd']),
                ('rf', trained_models['rf']),
                ('gb', trained_models['gb'])
            ],
            voting='soft',
            weights=[2, 2, 1, 1]
        )
        
        print('Training Ensemble...')
        self.model.fit(X_train_vectors, y_train)
        
        print('\nEvaluating Ensemble Model...')
        y_pred = self.model.predict(X_test_vectors)
        y_proba = self.model.predict_proba(X_test_vectors)
        
        metrics = self._calculate_metrics(y_test, y_pred, y_proba, unique_intents)
        self._print_metrics(metrics, unique_intents, y_test, y_pred)
        
        print('\nCross-validation (10-fold)...')
        skf = StratifiedKFold(n_splits=10, shuffle=True, random_state=42)
        cv_scores = cross_val_score(
            self.model, 
            X_train_vectors, 
            y_train, 
            cv=skf, 
            scoring='f1_weighted',
            n_jobs=-1
        )
        print(f'Mean F1: {cv_scores.mean():.4f} (+/- {cv_scores.std() * 2:.4f})')
        
        return metrics
    
    def train_transformer(self, texts: List[str], intents: List[str]):
        if not TRANSFORMERS_AVAILABLE:
            print("Warning: Transformers not available")
            return None
        
        print('\nTraining Transformer Model (AraBERT)...')
        
        unique_intents = sorted(list(set(intents)))
        self.intent_labels = unique_intents
        y_encoded = self.label_encoder.fit_transform(intents)
        
        try:
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            base_model = AutoModelForSequenceClassification.from_pretrained(
                self.model_name,
                num_labels=len(unique_intents)
            )
        except Exception as e:
            print(f"Warning: Error loading model: {e}")
            print("Using alternative model...")
            self.model_name = 'bert-base-multilingual-cased'
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            base_model = AutoModelForSequenceClassification.from_pretrained(
                self.model_name,
                num_labels=len(unique_intents)
            )
        
        def tokenize_function(examples):
            return self.tokenizer(
                examples['text'],
                padding='max_length',
                truncation=True,
                max_length=128
            )
        
        df = pd.DataFrame({'text': texts, 'label': y_encoded})
        dataset = Dataset.from_pandas(df)
        tokenized_dataset = dataset.map(tokenize_function, batched=True)
        
        X_train, X_test = train_test_split(tokenized_dataset, test_size=0.2, random_state=42)
        
        training_args = TrainingArguments(
            output_dir='./results',
            num_train_epochs=10,
            per_device_train_batch_size=16,
            per_device_eval_batch_size=16,
            warmup_steps=100,
            weight_decay=0.01,
            logging_dir='./logs',
            logging_steps=50,
            evaluation_strategy='epoch',
            save_strategy='epoch',
            load_best_model_at_end=True,
            metric_for_best_model='f1',
            greater_is_better=True,
            learning_rate=2e-5,
            fp16=True
        )
        
        def compute_metrics(eval_pred):
            predictions, labels = eval_pred
            predictions = np.argmax(predictions, axis=1)
            return {
                'accuracy': accuracy_score(labels, predictions),
                'f1': f1_score(labels, predictions, average='weighted')
            }
        
        trainer = Trainer(
            model=base_model,
            args=training_args,
            train_dataset=X_train,
            eval_dataset=X_test,
            compute_metrics=compute_metrics,
            callbacks=[EarlyStoppingCallback(early_stopping_patience=3)]
        )
        
        print('Starting training...')
        trainer.train()
        
        self.model = trainer.model
        self.tokenizer = self.tokenizer
        
        print('Transformer Model training completed')
        return {'model_type': 'transformer', 'model_name': self.model_name}
    
    def train(self, dataset_path: str, use_transformer: bool = False, hyperparameter_tuning: bool = False):
        print('=' * 80)
        print('Starting advanced NLU model training')
        print('=' * 80)
        
        print('\nLoading dataset...')
        dataset = self.load_dataset(dataset_path, augment=True)
        
        texts = []
        intents = []
        
        for example in dataset:
            processed_text = self.preprocessor.preprocess(example['text'])
            texts.append(processed_text)
            intents.append(example['intent'])
        
        print(f'Dataset statistics:')
        print(f'  Total examples: {len(texts)}')
        print(f'  Number of intents: {len(set(intents))}')
        print(f'  Intent distribution:')
        intent_counts = Counter(intents)
        for intent, count in intent_counts.most_common():
            print(f'    - {intent}: {count} examples ({count/len(intents)*100:.1f}%)')
        
        training_start = datetime.now()
        
        if use_transformer and TRANSFORMERS_AVAILABLE:
            metrics = self.train_transformer(texts, intents)
        else:
            metrics = self.train_sklearn_ensemble(texts, intents)
        
        training_end = datetime.now()
        training_duration = (training_end - training_start).total_seconds()
        
        print(f'\nTraining duration: {training_duration:.2f} seconds')
        
        metadata = {
            'model_type': 'transformer' if use_transformer else 'ensemble',
            'training_date': training_start.isoformat(),
            'training_duration_seconds': training_duration,
            'dataset_size': len(texts),
            'num_intents': len(set(intents)),
            'metrics': metrics if metrics else {},
            'model_name': self.model_name if use_transformer else 'ensemble'
        }
        
        self.save_model(metadata)
        self._save_training_log(metadata)
        
        print('\n' + '=' * 80)
        print('Training completed successfully!')
        print('=' * 80)
        
        return metadata
    
    def _calculate_metrics(self, y_true, y_pred, y_proba, labels):
        accuracy = accuracy_score(y_true, y_pred)
        precision, recall, f1, support = precision_recall_fscore_support(
            y_true, y_pred, average=None, labels=range(len(labels)), zero_division=0
        )
        
        weighted_f1 = f1_score(y_true, y_pred, average='weighted')
        macro_f1 = f1_score(y_true, y_pred, average='macro')
        kappa = cohen_kappa_score(y_true, y_pred)
        mcc = matthews_corrcoef(y_true, y_pred)
        
        return {
            'accuracy': accuracy,
            'weighted_f1': weighted_f1,
            'macro_f1': macro_f1,
            'kappa': kappa,
            'mcc': mcc,
            'per_class': {
                'precision': precision.tolist(),
                'recall': recall.tolist(),
                'f1': f1.tolist(),
                'support': support.tolist()
            }
        }
    
    def _print_metrics(self, metrics, labels, y_test, y_pred):
        print(f'\nComprehensive Metrics:')
        print(f'  Accuracy: {metrics["accuracy"]:.4f}')
        print(f'  Weighted F1: {metrics["weighted_f1"]:.4f}')
        print(f'  Macro F1: {metrics["macro_f1"]:.4f}')
        print(f'  Cohen\'s Kappa: {metrics["kappa"]:.4f}')
        print(f'  Matthews Correlation: {metrics["mcc"]:.4f}')
        
        print(f'\nDetailed report per intent:')
        print(classification_report(
            y_test, 
            y_pred, 
            target_names=labels,
            zero_division=0,
            digits=4
        ))
        
        print(f'\nConfusion Matrix:')
        cm = confusion_matrix(y_test, y_pred)
        print(cm)
    
    def predict(self, text: str) -> dict:
        if self.model is None:
            return {
                'intent': 'unknown',
                'confidence': 0.0,
                'entities': {},
                'original_text': text
            }
        
        processed_text = self.preprocessor.preprocess(text)
        
        if self.use_transformer and self.tokenizer:
            inputs = self.tokenizer(
                processed_text,
                return_tensors='pt',
                padding=True,
                truncation=True,
                max_length=128
            )
            with torch.no_grad():
                outputs = self.model(**inputs)
                probs = torch.nn.functional.softmax(outputs.logits, dim=-1)
                intent_idx = torch.argmax(probs, dim=-1).item()
                confidence = float(probs[0][intent_idx])
        else:
            text_vector = self.vectorizer.transform([processed_text])
            intent_idx = self.model.predict(text_vector)[0]
            probs = self.model.predict_proba(text_vector)[0]
            confidence = float(probs[intent_idx])
        
        intent = self.intent_labels[intent_idx] if intent_idx < len(self.intent_labels) else 'unknown'
        
        entities = self._extract_entities(text, intent)
        
        return {
            'intent': intent,
            'confidence': confidence,
            'entities': entities,
            'original_text': text
        }
    
    def _extract_entities(self, text: str, intent: str) -> dict:
        entities = {}
        text_lower = text.lower()
        
        if intent == 'search':
            patterns = [
                r'عن\s+([\u0600-\u06FF\s]+)',
                r'بحث\s+([\u0600-\u06FF\s]+)',
                r'دور\s+([\u0600-\u06FF\s]+)'
            ]
            for pattern in patterns:
                match = re.search(pattern, text_lower)
                if match:
                    entities['product'] = match.group(1).strip()
                    break
        
        if intent == 'delete_order':
            order_match = re.search(r'(\d+)', text)
            if order_match:
                entities['order_id'] = order_match.group(1)
        
        if intent == 'select_product':
            product_match = re.search(r'(\d+)', text)
            if product_match:
                entities['product_number'] = product_match.group(1)
        
        return entities
    
    def save_model(self, metadata: dict):
        os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
        
        if self.use_transformer:
            model_dir = os.path.join(os.path.dirname(__file__), 'data', 'transformer_model')
            os.makedirs(model_dir, exist_ok=True)
            self.model.save_pretrained(model_dir)
            self.tokenizer.save_pretrained(model_dir)
            print(f'Saved Transformer Model to: {model_dir}')
        else:
            model_data = {
                'model': self.model,
                'vectorizer': self.vectorizer,
                'intent_labels': self.intent_labels,
                'label_encoder': self.label_encoder
            }
            joblib.dump(model_data, self.model_path)
            print(f'Saved Ensemble Model to: {self.model_path}')
        
        with open(self.metadata_path, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, ensure_ascii=False, indent=2)
        print(f'Saved Metadata to: {self.metadata_path}')
    
    def load_model(self):
        if os.path.exists(self.metadata_path):
            with open(self.metadata_path, 'r', encoding='utf-8') as f:
                metadata = json.load(f)
            
            if metadata.get('model_type') == 'transformer' and TRANSFORMERS_AVAILABLE:
                model_dir = os.path.join(os.path.dirname(__file__), 'data', 'transformer_model')
                if os.path.exists(model_dir):
                    try:
                        self.model = AutoModelForSequenceClassification.from_pretrained(model_dir)
                        self.tokenizer = AutoTokenizer.from_pretrained(model_dir)
                        self.use_transformer = True
                        print(f'Loaded Transformer Model from: {model_dir}')
                        return True
                    except Exception as e:
                        print(f'Warning: Error loading Transformer: {e}')
            
            if os.path.exists(self.model_path):
                try:
                    model_data = joblib.load(self.model_path)
                    self.model = model_data['model']
                    self.vectorizer = model_data['vectorizer']
                    self.intent_labels = model_data['intent_labels']
                    self.label_encoder = model_data.get('label_encoder', LabelEncoder())
                    self.use_transformer = False
                    print(f'Loaded Ensemble Model from: {self.model_path}')
                    return True
                except Exception as e:
                    print(f'Warning: Error loading model: {e}')
                    return False
        return False
    
    def _save_training_log(self, metadata: dict):
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'metadata': metadata
        }
        
        if os.path.exists(self.training_log_path):
            with open(self.training_log_path, 'r', encoding='utf-8') as f:
                logs = json.load(f)
        else:
            logs = []
        
        logs.append(log_entry)
        
        with open(self.training_log_path, 'w', encoding='utf-8') as f:
            json.dump(logs, f, ensure_ascii=False, indent=2)

def create_massive_dataset():
    dataset = []
    
    search_patterns = [
        'ابحث عن {product}', 'أريد البحث عن {product}', 'دور على {product}',
        'عايز أبحث عن {product}', 'أبغى أبحث عن {product}', 'أريد {product}',
        'ابحث لي عن {product}', 'دور لي على {product}', 'عرض لي {product}',
        'شو في {product}', 'إيش في {product}', 'عرض {product}',
        'أريد شراء {product}', 'أبي أشتري {product}', 'عايز أشتري {product}',
        'أبغى أشتري {product}', 'أريد شراء {product}', 'أبي أشتري {product}'
    ]
    
    products = ['هاتف', 'لابتوب', 'قهوة', 'منتج', 'آيفون', 'سامسونج', 'ماك بوك', 
                'بلايستيشن', 'سماعة', 'حذاء', 'كتاب', 'رواية', 'إلكترونيات', 
                'ملابس', 'أطعمة', 'كتب', 'أثاث', 'أجهزة']
    
    for pattern in search_patterns:
        for product in products:
            dataset.append({
                'intent': 'search',
                'text': pattern.format(product=product),
                'entities': {'product': product}
            })
    
    add_to_cart_patterns = [
        'أضف للسلة', 'ضيف للسلة', 'أضف للعربة', 'ضيف للعربة',
        'أضف هذا المنتج', 'ضيف هذا', 'أريد إضافة', 'أبي أضيف',
        'عايز أضيف', 'أبغى أضيف', 'حط في السلة', 'حطيه',
        'أضف المنتج', 'ضيف المنتج', 'أضف هذا', 'ضيف هذا',
        'أريد إضافة هذا', 'أبي أضيف هذا', 'عايز أضيف للسلة',
        'أبغى أضيف للعربة', 'أضف للعربة', 'ضيف للعربة'
    ]
    
    for text in add_to_cart_patterns:
        dataset.append({'intent': 'add_to_cart', 'text': text, 'entities': {}})
    
    view_cart_patterns = [
        'عرض السلة', 'شو في السلة', 'إيش في السلة', 'اقرأ السلة',
        'اعرض السلة', 'أعرض السلة', 'السلة إيش فيها', 'شو محتوى السلة',
        'عرض العربة', 'شو في العربة', 'إيش في العربة', 'اقرأ العربة',
        'اعرض العربة', 'أعرض العربة', 'العربة إيش فيها', 'شو محتوى العربة',
        'ما في السلة', 'ماذا في السلة', 'عرض محتويات السلة', 'أعرض محتويات السلة',
        'السلة', 'العربة', 'المشتريات', 'الطلبات في السلة'
    ]
    
    for text in view_cart_patterns:
        dataset.append({'intent': 'view_cart', 'text': text, 'entities': {}})
    
    checkout_patterns = [
        'إتمام الشراء', 'أكمل الطلب', 'أكمل الشراء', 'إتمام الطلب',
        'أريد الشراء', 'أبي أشتري', 'عايز أشتري', 'أبغى أشتري',
        'تأكيد الطلب', 'تأكيد الشراء', 'أكيد الطلب', 'أكيد الشراء',
        'دفع', 'أدفع', 'أريد الدفع', 'أبي أدفع', 'عايز أدفع', 'أبغى أدفع',
        'إنهاء الطلب', 'إنهاء الشراء', 'إنهاء', 'أكمل', 'تمام', 'نعم',
        'أكمل عملية الشراء', 'إتمام عملية الشراء', 'تأكيد عملية الشراء'
    ]
    
    for text in checkout_patterns:
        dataset.append({'intent': 'checkout', 'text': text, 'entities': {}})
    
    navigate_patterns = [
        'اذهب إلى الحساب', 'اذهب للحساب', 'افتح الحساب', 'عرض الحساب',
        'الحساب', 'حسابي', 'الملف الشخصي', 'البروفايل',
        'اذهب لصفحة الحساب', 'افتح صفحة الحساب', 'عرض صفحة الحساب',
        'شو في حسابي', 'إيش في حسابي', 'حسابي إيش فيه', 'ما في حسابي',
        'عرض حسابي', 'أعرض حسابي', 'اقرأ حسابي', 'اعرض حسابي',
        'الملف الشخصي', 'البروفايل', 'صفحة الحساب', 'حساب المستخدم'
    ]
    
    for text in navigate_patterns:
        dataset.append({'intent': 'navigate_to_account', 'text': text, 'entities': {}})
    
    address_patterns = [
        'أضف عنوان جديد', 'إضافة عنوان', 'أضيف عنوان', 'ضيف عنوان',
        'أضف عنوان', 'إضافة عنوان جديد', 'أريد إضافة عنوان', 'أبي أضيف عنوان',
        'عايز أضيف عنوان', 'أبغى أضيف عنوان', 'عنوان جديد', 'أضف عنوان للشحن',
        'إضافة عنوان الشحن', 'أضف عنوان التوصيل', 'إضافة عنوان التوصيل',
        'عنوان جديد للشحن', 'عنوان جديد للتوصيل', 'إضافة عنوان جديد'
    ]
    
    for text in address_patterns:
        dataset.append({'intent': 'add_address', 'text': text, 'entities': {}})
    
    payment_patterns = [
        'أضف طريقة دفع', 'إضافة طريقة دفع', 'أضيف طريقة دفع', 'ضيف طريقة دفع',
        'أضف بطاقة', 'إضافة بطاقة', 'أضيف بطاقة', 'ضيف بطاقة',
        'أضف كارت', 'إضافة كارت', 'أضف محفظة', 'إضافة محفظة',
        'أريد إضافة طريقة دفع', 'أبي أضيف بطاقة', 'عايز أضيف كارت', 'أبغى أضيف محفظة',
        'طريقة دفع جديدة', 'بطاقة جديدة', 'كارت جديد', 'محفظة جديدة',
        'إضافة طريقة دفع جديدة', 'أضف طريقة دفع جديدة'
    ]
    
    for text in payment_patterns:
        dataset.append({'intent': 'add_payment_method', 'text': text, 'entities': {}})
    
    delete_order_patterns = [
        'احذف الطلب رقم {num}', 'حذف الطلب رقم {num}', 'أحذف الطلب رقم {num}',
        'شيل الطلب رقم {num}', 'احذف الطلب', 'حذف الطلب', 'أحذف الطلب',
        'شيل الطلب', 'احذف طلب', 'حذف طلب', 'أحذف طلب', 'شيل طلب',
        'أريد حذف الطلب', 'أبي أحذف الطلب', 'عايز أحذف الطلب', 'أبغى أحذف الطلب'
    ]
    
    for pattern in delete_order_patterns:
        for num in range(1, 10):
            text = pattern.format(num=num)
            order_id = re.search(r'\d+', text)
            entities = {'order_id': order_id.group(0)} if order_id else {}
            dataset.append({'intent': 'delete_order', 'text': text, 'entities': entities})
    
    read_desc_patterns = [
        'اقرأ الوصف', 'اقرا الوصف', 'اقرأ لي الوصف', 'اقرا لي الوصف',
        'وصف المنتج', 'وصف', 'اقرأ وصف المنتج', 'اقرا وصف المنتج',
        'أريد معرفة الوصف', 'أبي أعرف الوصف', 'عايز أعرف الوصف', 'أبغى أعرف الوصف',
        'شو الوصف', 'إيش الوصف', 'ما الوصف', 'ماذا الوصف',
        'اعرض الوصف', 'أعرض الوصف', 'اقرأ المزيد', 'اقرا المزيد',
        'وصف المنتج', 'ما هو الوصف', 'ماذا الوصف', 'أخبرني عن المنتج'
    ]
    
    for text in read_desc_patterns:
        dataset.append({'intent': 'read_description', 'text': text, 'entities': {}})
    
    view_products_patterns = [
        'عرض المنتجات', 'المنتجات', 'أعرض المنتجات', 'اعرض المنتجات',
        'شو المنتجات', 'إيش المنتجات', 'ما المنتجات', 'ماذا المنتجات',
        'عرض المتجر', 'المتجر', 'أعرض المتجر', 'اعرض المتجر',
        'شو في المتجر', 'إيش في المتجر', 'ما في المتجر', 'ماذا في المتجر',
        'جميع المنتجات', 'كل المنتجات', 'عرض جميع المنتجات', 'أعرض جميع المنتجات',
        'كل المنتجات المتاحة', 'جميع المنتجات المتاحة', 'عرض الكل'
    ]
    
    for text in view_products_patterns:
        dataset.append({'intent': 'view_products', 'text': text, 'entities': {}})
    
    remove_cart_patterns = [
        'احذف من السلة', 'حذف من السلة', 'أحذف من السلة', 'شيل من السلة',
        'احذف المنتج', 'حذف المنتج', 'أحذف المنتج', 'شيل المنتج',
        'أزل من السلة', 'أزل المنتج', 'احذف المنتج من السلة', 'حذف المنتج من السلة',
        'شيل المنتج من السلة', 'أزل المنتج من السلة', 'احذف هذا', 'حذف هذا',
        'أزل هذا', 'شيل هذا', 'احذف المنتج من العربة', 'حذف المنتج من العربة'
    ]
    
    for text in remove_cart_patterns:
        dataset.append({'intent': 'remove_from_cart', 'text': text, 'entities': {}})
    
    logout_patterns = [
        'تسجيل خروج', 'خروج', 'سجل خروج', 'أخرج', 'تسجيل الخروج',
        'سجل الخروج', 'أريد الخروج', 'أبي أخرج', 'عايز أخرج', 'أبغى أخرج',
        'سجلني خارج', 'أخرجني', 'تسجيل خروج من الحساب', 'خروج من الحساب'
    ]
    
    for text in logout_patterns:
        dataset.append({'intent': 'logout', 'text': text, 'entities': {}})
    
    settings_patterns = [
        'الإعدادات', 'إعدادات', 'الضبط', 'ضبط', 'الخيارات', 'خيارات',
        'اذهب للإعدادات', 'افتح الإعدادات', 'عرض الإعدادات', 'الإعدادات إيش',
        'شو الإعدادات', 'إيش الإعدادات', 'صفحة الإعدادات', 'إعدادات التطبيق'
    ]
    
    for text in settings_patterns:
        dataset.append({'intent': 'settings', 'text': text, 'entities': {}})
    
    complete_order_patterns = [
        'تأكيد', 'أكيد', 'تمام', 'نعم', 'إتمام', 'أكمل', 'تأكيد الطلب',
        'تأكيد الشراء', 'أكيد الطلب', 'أكيد الشراء', 'إتمام الطلب', 'إتمام الشراء',
        'أكمل الطلب', 'أكمل الشراء', 'تأكيد وإتمام', 'أكيد وإتمام'
    ]
    
    for text in complete_order_patterns:
        dataset.append({'intent': 'complete_order', 'text': text, 'entities': {}})
    
    dataset_path = os.path.join(os.path.dirname(__file__), 'data', 'nlu_dataset.json')
    os.makedirs(os.path.dirname(dataset_path), exist_ok=True)
    
    with open(dataset_path, 'w', encoding='utf-8') as f:
        json.dump(dataset, f, ensure_ascii=False, indent=2)
    
    print(f'Created comprehensive dataset with {len(dataset)} examples')
    return dataset_path

if __name__ == '__main__':
    print('=' * 80)
    print('Advanced NLU Model Training System - World Class Level')
    print('=' * 80)
    
    if not TRANSFORMERS_AVAILABLE:
        print('\nNote: Transformer models are not available.')
        print('You can use the Ensemble Model (sklearn) which is fast and accurate.')
        print('To enable Transformer models, install PyTorch >= 2.2:')
        print('  pip install torch>=2.2.0')
        print()
    
    print('\nStep 1: Creating comprehensive dataset...')
    dataset_path = create_massive_dataset()
    print(f'Dataset created at: {dataset_path}')
    
    print('\nStep 2: Initializing model...')
    if TRANSFORMERS_AVAILABLE:
        use_transformer = input('\nUse Transformer Model? (y/n): ').lower() == 'y'
    else:
        print('Using Ensemble Model (sklearn) - Transformer models not available')
        use_transformer = False
    
    model = ArabicNLUModel(use_transformer=use_transformer)
    
    print('\nStep 3: Starting advanced training...')
    metadata = model.train(dataset_path, use_transformer=use_transformer)
    
    print('\nStep 4: Testing model on diverse examples...')
    test_cases = [
        'ابحث عن هاتف',
        'أضف للسلة',
        'اذهب إلى الحساب',
        'أضف عنوان جديد',
        'احذف الطلب رقم 5',
        'عرض السلة',
        'إتمام الشراء',
        'اقرأ الوصف',
        'عرض المنتجات',
        'احذف من السلة',
        'عايز أبحث عن لابتوب',
        'أبغى أضيف بطاقة',
        'شو في السلة'
    ]
    
    print('\nTest Results:')
    print('-' * 80)
    for text in test_cases:
        result = model.predict(text)
        print(f'Text: "{text}"')
        print(f'  Intent: {result["intent"]} | Confidence: {result["confidence"]:.2%}')
        if result['entities']:
            print(f'  Entities: {result["entities"]}')
        print()
    
    print('=' * 80)
    print('Training completed successfully! Model is ready for use.')
    print('=' * 80)
