import re
from typing import Dict, List, Optional, Tuple

class NLUProcessor:
    def __init__(self):
        self.intents = {
            'register': ['سجل', 'تسجيل', 'إنشاء حساب', 'حساب جديد', 'سجلني'],
            'login': ['دخول', 'تسجيل دخول', 'سجل دخول', 'دخل'],
            'search_product': ['ابحث', 'بحث', 'أريد', 'أبحث عن', 'ابحث عن', 'عرض', 'أعرض'],
            'open_product': ['افتح', 'عرض', 'أعرض', 'تفاصيل', 'أريد معرفة', 'أخبرني عن'],
            'add_to_cart': ['أضف', 'أضيف', 'إضافة', 'ضع', 'ضعي', 'أريد إضافة', 'أضف للسلة'],
            'checkout': ['اشتري', 'شراء', 'دفع', 'أدفع', 'أكمل الشراء', 'إنهاء', 'أكمل'],
            'order_status': ['حالة', 'حالة الطلب', 'أين طلبي', 'متى', 'متى سيصل'],
            'request_return': ['استرجاع', 'إرجاع', 'أريد إرجاع', 'أريد استرجاع', 'استبدال'],
            'ask_recommendation': ['اقترح', 'اقتراح', 'ما الذي تنصح', 'ما الأفضل', 'أفضل']
        }
        
        self.entities_patterns = {
            'product_name': [
                r'([هق]اتف|حاسوب|لابتوب|قميص|قهوة|كتاب|رواية|إلكترونيات|ملابس|طعام)',
                r'([\u0600-\u06FF\s]+)'
            ],
            'quantity': [
                r'(\d+)\s*(قطعة|وحدة|عدد)',
                r'(\d+)'
            ],
            'category': [
                r'(إلكترونيات|ملابس|طعام|كتب|منزل)'
            ],
            'payment_method': [
                r'(بطاقة|كارت|عند الاستلام|نقد)'
            ]
        }
    
    def parse_intent(self, text: str) -> Tuple[str, float]:
        text_lower = text.lower().strip()
        best_intent = 'unknown'
        best_score = 0.0
        
        for intent, keywords in self.intents.items():
            score = 0.0
            matches = sum(1 for keyword in keywords if keyword in text_lower)
            if matches > 0:
                score = matches / len(keywords)
                if score > best_score:
                    best_score = score
                    best_intent = intent
        
        return best_intent, best_score
    
    def extract_entities(self, text: str, intent: str) -> Dict[str, any]:
        entities = {}
        text_lower = text.lower()
        
        for entity_type, patterns in self.entities_patterns.items():
            for pattern in patterns:
                match = re.search(pattern, text_lower)
                if match:
                    entities[entity_type] = match.group(1).strip()
                    break
        
        if intent == 'add_to_cart':
            quantity_match = re.search(r'(\d+)', text)
            if quantity_match:
                entities['quantity'] = int(quantity_match.group(1))
            else:
                entities['quantity'] = 1
        
        if intent == 'search_product':
            product_match = re.search(r'عن\s+([\u0600-\u06FF\s]+)', text)
            if product_match:
                entities['product_name'] = product_match.group(1).strip()
        
        return entities
    
    def process(self, text: str) -> Dict[str, any]:
        intent, confidence = self.parse_intent(text)
        entities = self.extract_entities(text, intent)
        
        return {
            'intent': intent,
            'confidence': confidence,
            'entities': entities,
            'original_text': text
        }
    
    def generate_response(self, nlu_result: Dict[str, any], context: Optional[Dict] = None) -> str:
        intent = nlu_result.get('intent', 'unknown')
        entities = nlu_result.get('entities', {})
        
        responses = {
            'register': 'سأساعدك في إنشاء حساب جديد. ما هو اسمك؟',
            'login': 'سأساعدك في تسجيل الدخول. ما هو بريدك الإلكتروني أو رقم هاتفك؟',
            'search_product': f"سأبحث عن {entities.get('product_name', 'المنتجات')}",
            'open_product': f"سأعرض لك تفاصيل {entities.get('product_name', 'المنتج')}",
            'add_to_cart': f"تمت إضافة {entities.get('quantity', 1)} قطعة إلى السلة",
            'checkout': 'سأكمل عملية الشراء. ما هي طريقة الدفع التي تفضلها؟',
            'order_status': 'سأتحقق من حالة طلبك',
            'request_return': 'سأساعدك في طلب الاسترجاع',
            'ask_recommendation': 'سأقترح عليك بعض المنتجات المناسبة',
            'unknown': 'لم أفهم طلبك. هل يمكنك إعادة صياغته؟'
        }
        
        return responses.get(intent, responses['unknown'])

