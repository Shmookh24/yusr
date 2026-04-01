import json
import os
from train_nlu_model import ArabicNLUModel, create_massive_dataset
import numpy as np
from sklearn.model_selection import ParameterGrid
import time

class AdvancedTrainingPipeline:
    def __init__(self):
        self.results = []
        self.best_model = None
        self.best_score = 0
        
    def hyperparameter_tuning(self, dataset_path: str):
        print('=' * 80)
        print('Advanced Hyperparameter Tuning')
        print('=' * 80)
        
        param_grid = {
            'max_features': [5000, 10000, 15000],
            'ngram_range': [(1, 3), (1, 4), (2, 4)],
            'max_df': [0.85, 0.9, 0.95],
            'min_df': [1, 2, 3]
        }
        
        print(f'\nNumber of combinations: {len(list(ParameterGrid(param_grid)))}')
        print('Starting search...')
        
        best_params = None
        best_score = 0
        
        for i, params in enumerate(ParameterGrid(param_grid)):
            print(f'\nCombination {i+1}/{len(list(ParameterGrid(param_grid)))}: {params}')
            
            model = ArabicNLUModel()
            model.vectorizer = None
            
            try:
                metadata = model.train(dataset_path, use_transformer=False)
                score = metadata.get('metrics', {}).get('weighted_f1', 0)
                
                if score > best_score:
                    best_score = score
                    best_params = params
                    self.best_model = model
                
                self.results.append({
                    'params': params,
                    'score': score,
                    'metadata': metadata
                })
                
                print(f'Result: {score:.4f}')
            except Exception as e:
                print(f'Error: {e}')
        
        print(f'\nBest combination: {best_params}')
        print(f'Best score: {best_score:.4f}')
        
        return best_params, best_score
    
    def cross_validation_analysis(self, dataset_path: str, n_splits: int = 10):
        print('=' * 80)
        print(f'Cross-Validation Analysis ({n_splits}-fold)')
        print('=' * 80)
        
        from sklearn.model_selection import StratifiedKFold
        from train_nlu_model import AdvancedTextPreprocessor
        
        with open(dataset_path, 'r', encoding='utf-8') as f:
            dataset = json.load(f)
        
        preprocessor = AdvancedTextPreprocessor()
        texts = [preprocessor.preprocess(ex['text']) for ex in dataset]
        intents = [ex['intent'] for ex in dataset]
        
        from sklearn.preprocessing import LabelEncoder
        le = LabelEncoder()
        y = le.fit_transform(intents)
        
        skf = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)
        
        fold_scores = []
        
        for fold, (train_idx, test_idx) in enumerate(skf.split(texts, y)):
            print(f'\nFold {fold + 1}/{n_splits}...')
            
            X_train = [texts[i] for i in train_idx]
            X_test = [texts[i] for i in test_idx]
            y_train = [y[i] for i in train_idx]
            y_test = [y[i] for i in test_idx]
            
            model = ArabicNLUModel()
            metrics = model.train_sklearn_ensemble(X_train, y_train)
            
            fold_scores.append(metrics.get('weighted_f1', 0))
            print(f'Fold {fold + 1} F1: {fold_scores[-1]:.4f}')
        
        print(f'\nCross-Validation Results:')
        print(f'  Mean F1: {np.mean(fold_scores):.4f}')
        print(f'  Std F1: {np.std(fold_scores):.4f}')
        print(f'  Min F1: {np.min(fold_scores):.4f}')
        print(f'  Max F1: {np.max(fold_scores):.4f}')
        
        return fold_scores
    
    def model_comparison(self, dataset_path: str):
        print('=' * 80)
        print('Model Comparison')
        print('=' * 80)
        
        models_to_test = [
            ('Ensemble', False),
            ('Transformer', True) if os.path.exists('transformers') else None
        ]
        
        models_to_test = [m for m in models_to_test if m is not None]
        
        comparison_results = []
        
        for name, use_transformer in models_to_test:
            print(f'\nTesting {name}...')
            start_time = time.time()
            
            model = ArabicNLUModel(use_transformer=use_transformer)
            metadata = model.train(dataset_path, use_transformer=use_transformer)
            
            training_time = time.time() - start_time
            
            comparison_results.append({
                'name': name,
                'metrics': metadata.get('metrics', {}),
                'training_time': training_time,
                'model_size': self._estimate_model_size(model)
            })
            
            print(f'{name} - F1: {metadata.get("metrics", {}).get("weighted_f1", 0):.4f}')
        
        print('\nComparison Table:')
        print('-' * 80)
        for result in comparison_results:
            print(f'\n{result["name"]}:')
            print(f'  F1 Score: {result["metrics"].get("weighted_f1", 0):.4f}')
            print(f'  Accuracy: {result["metrics"].get("accuracy", 0):.4f}')
            print(f'  Training Time: {result["training_time"]:.2f}s')
            print(f'  Model Size: {result["model_size"]:.2f} MB')
        
        return comparison_results
    
    def _estimate_model_size(self, model):
        import sys
        size = sys.getsizeof(model.model) if model.model else 0
        if model.vectorizer:
            size += sys.getsizeof(model.vectorizer)
        return size / (1024 * 1024)

if __name__ == '__main__':
    print('Advanced Training System - Complete Pipeline')
    print('=' * 80)
    
    dataset_path = create_massive_dataset()
    
    pipeline = AdvancedTrainingPipeline()
    
    print('\n1. Model Comparison...')
    comparison = pipeline.model_comparison(dataset_path)
    
    print('\n2. Cross-Validation Analysis...')
    cv_scores = pipeline.cross_validation_analysis(dataset_path)
    
    print('\nAdvanced analysis completed!')
