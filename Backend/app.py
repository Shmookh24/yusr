from flask import Flask, request, jsonify
from flask_cors import CORS
import hashlib, os
from modules.db import Database

try:
    from train_nlu_model import ArabicNLUModel
    nlu_model = ArabicNLUModel()
    nlu_model_loaded = nlu_model.load_model()
    if nlu_model_loaded: print('NLU model loaded successfully')
    else: print('Warning: NLU model not found, using default system')
except Exception as e:
    print(f'Warning: Error loading NLU model: {e}')
    nlu_model = None
    nlu_model_loaded = False

app = Flask(__name__)
CORS(app)

db_path = os.path.join(os.path.dirname(__file__), 'data', 'yusr.db')
db = Database(db_path)

@app.route('/nlu', methods=['POST'])
def nlu():
    try:
        if not request.json:
            return jsonify({
                'intent': 'unknown',
                'message': 'لم يتم إرسال بيانات',
                'speak_text': 'حدث خطأ في الطلب'
            }), 400
        
        data = request.json
        text = data.get('text', '').strip() if data else ''
        
        if not text:
            return jsonify({
                'intent': 'unknown',
                'message': 'لم يتم إرسال نص',
                'speak_text': 'لم أسمع أي شيء'
            }), 400
        
        if nlu_model_loaded and nlu_model:
            try:
                result = nlu_model.predict(text)
                confidence_threshold = 0.3 if not nlu_model.use_transformer else 0.5
                if result['confidence'] > confidence_threshold:
                    return jsonify({
                        'intent': result['intent'],
                        'entities': result.get('entities', {}),
                        'confidence': float(result['confidence']),
                        'speak_text': _generate_speak_text(result['intent'], result.get('entities', {}))
                    })
            except Exception as e:
                print(f'Warning: Prediction error: {e}')
                pass
        
        text_lower = text.lower()
        
        # البحث بالصوت - دعم لهجات مختلفة
        search_keywords = ['أريد البحث عن', 'ابحث عن', 'بحث عن', 'أبحث عن', 'عرض', 'بحث', 'أبحث', 
                          'دور', 'دور على', 'أريد', 'عايز', 'عاوز', 'أبي', 'أبغى']
        if any(keyword in text_lower for keyword in search_keywords):
            query = text
            # استخراج كلمة البحث
            for keyword in ['أريد البحث عن', 'ابحث عن', 'بحث عن', 'أبحث عن', 'عرض', 'دور على', 'دور']:
                if keyword in text_lower:
                    query = text_lower.replace(keyword, '').strip()
                    break
            # إزالة كلمات إضافية
            query = query.replace('عن', '').replace('على', '').strip()
            if query:
                return jsonify({
                    'intent': 'search',
                    'query': query,
                    'speak_text': f'جاري البحث عن {query}'
                })
        
        # إضافة للسلة - دعم لهجات مختلفة
        add_keywords = ['أضف للسلة', 'أضف', 'إضافة', 'أضيف', 'ضيف', 'ضيف للسلة', 
                       'حط', 'حط في السلة', 'أضف للعربة', 'ضيف للعربة']
        if any(keyword in text_lower for keyword in add_keywords):
            # استخراج اسم المنتج
            product_name = text_lower
            for keyword in add_keywords:
                if keyword in product_name:
                    product_name = product_name.replace(keyword, '').strip()
                    break
            return jsonify({
                'intent': 'add_to_cart',
                'product_name': product_name if product_name else None,
                'speak_text': 'تمت إضافة المنتج للسلة'
            })
        
        # حالة الطلب
        order_status_keywords = ['ما حالة طلبي', 'حالة الطلب', 'حالة', 'طلبي', 'أين طلبي', 
                                'وين طلبي', 'شو حالة الطلب', 'إيش حالة الطلب']
        if any(keyword in text_lower for keyword in order_status_keywords):
            return jsonify({
                'intent': 'order_status',
                'speak_text': 'جاري التحقق من حالة الطلب'
            })
        
        # عرض السلة
        cart_keywords = ['السلة', 'عرض السلة', 'سلة', 'العربة', 'عربة', 'السلة إيش فيها',
                        'شو في السلة', 'إيش في السلة', 'اقرأ السلة', 'اعرض السلة']
        if any(keyword in text_lower for keyword in cart_keywords):
            return jsonify({
                'intent': 'view_cart',
                'speak_text': 'جاري عرض السلة'
            })
        
        # عرض المنتجات
        products_keywords = ['المنتجات', 'عرض المنتجات', 'المتجر', 'المتاجر', 'المنتجات إيش',
                           'شو المنتجات', 'إيش المنتجات', 'عرض المتجر']
        if any(keyword in text_lower for keyword in products_keywords):
            return jsonify({
                'intent': 'view_products',
                'speak_text': 'جاري عرض المنتجات'
            })
        
        # الملف الشخصي
        profile_keywords = ['حسابي', 'الملف الشخصي', 'الطلبات', 'طلباتي', 'حسابي إيش',
                          'شو في حسابي', 'إيش في حسابي', 'عرض حسابي']
        if any(keyword in text_lower for keyword in profile_keywords):
            return jsonify({
                'intent': 'view_profile',
                'speak_text': 'جاري عرض حسابك'
            })
        
        # إتمام الشراء - دعم لهجات مختلفة
        checkout_keywords = ['إتمام', 'شراء', 'دفع', 'تأكيد', 'أكيد', 'تمام', 'نعم', 'اشتري',
                           'أشتري', 'أكمل', 'أكمل الشراء', 'أكمل الطلب', 'تأكيد الطلب',
                           'تأكيد الشراء', 'إتمام الشراء', 'إتمام الطلب', 'أكمل الشراء']
        if any(keyword in text_lower for keyword in checkout_keywords):
            return jsonify({
                'intent': 'checkout',
                'speak_text': 'جاري إتمام عملية الشراء'
            })
        
        # قراءة الوصف
        read_keywords = ['اقرأ', 'اقرا', 'اقرأ الوصف', 'اقرأ المنتج', 'وصف', 'اقرأ لي',
                        'اقرا لي', 'اعرض', 'اعرض الوصف', 'شو الوصف', 'إيش الوصف']
        if any(keyword in text_lower for keyword in read_keywords):
            return jsonify({
                'intent': 'read_description',
                'speak_text': 'جاري قراءة الوصف'
            })
        
        # حذف من السلة
        remove_keywords = ['احذف', 'شيل', 'أحذف', 'شيل من السلة', 'احذف من السلة',
                          'أزل', 'أزل من السلة', 'حذف']
        if any(keyword in text_lower for keyword in remove_keywords):
            return jsonify({
                'intent': 'remove_from_cart',
                'speak_text': 'جاري حذف المنتج من السلة'
            })
        
        # اختيار منتج بالصوت
        select_keywords = ['المنتج رقم', 'اختر المنتج', 'المنتج', 'رقم', 'أختر',
                          'أختار', 'اختر', 'أريد', 'أبي', 'أبغى']
        if any(keyword in text_lower for keyword in select_keywords) and any(char.isdigit() for char in text):
            return jsonify({
                'intent': 'select_product',
                'speak_text': 'جاري اختيار المنتج'
            })
        
        # التنقل بين المنتجات
        navigate_keywords = ['التالي', 'السابق', 'التالي', 'اللي بعد', 'اللي قبل',
                            'التالي', 'التالي', 'التالي']
        if any(keyword in text_lower for keyword in navigate_keywords):
            return jsonify({
                'intent': 'navigate',
                'speak_text': 'جاري التنقل'
            })
        
        navigate_account_keywords = ['اذهب إلى الحساب', 'اذهب للحساب', 'الحساب', 'حسابي', 'الملف الشخصي',
                                     'اذهب لصفحة الحساب', 'افتح الحساب', 'عرض الحساب', 'شوف الحساب']
        if any(keyword in text_lower for keyword in navigate_account_keywords):
            return jsonify({
                'intent': 'navigate_to_account',
                'speak_text': 'جاري الانتقال إلى الحساب'
            })

        add_address_keywords = ['أضف عنوان', 'إضافة عنوان', 'عنوان جديد', 'أضيف عنوان', 'ضيف عنوان',
                                'أضف عنوان جديد', 'إضافة عنوان جديد', 'أريد إضافة عنوان']
        if any(keyword in text_lower for keyword in add_address_keywords):
            return jsonify({
                'intent': 'add_address',
                'speak_text': 'سأساعدك في إضافة عنوان جديد'
            })

        add_payment_keywords = ['أضف طريقة دفع', 'إضافة طريقة دفع', 'طريقة دفع جديدة', 'أضيف طريقة دفع',
                               'ضيف طريقة دفع', 'أضف بطاقة', 'إضافة بطاقة', 'أضف كارت', 'أضف محفظة']
        if any(keyword in text_lower for keyword in add_payment_keywords):
            return jsonify({
                'intent': 'add_payment_method',
                'speak_text': 'سأساعدك في إضافة طريقة دفع جديدة'
            })

        delete_order_keywords = ['احذف الطلب', 'حذف الطلب', 'أحذف الطلب', 'شيل الطلب', 'احذف طلب',
                                'حذف طلب', 'أحذف طلب', 'احذف الطلب رقم', 'حذف الطلب رقم']
        if any(keyword in text_lower for keyword in delete_order_keywords):
            return jsonify({
                'intent': 'delete_order',
                'speak_text': 'جاري حذف الطلب'
            })

        if any(char.isdigit() for char in text) and any(keyword in text_lower for keyword in ['عنوان', 'شارع', 'مدينة', 'حي', 'مبنى', 'شقة', 'بريدي']):
            return jsonify({
                'intent': 'collect_address_data',
                'speak_text': 'تم استلام البيانات'
            })

        if any(char.isdigit() for char in text) and any(keyword in text_lower for keyword in ['بطاقة', 'كارت', 'شهر', 'سنة', 'cvv', 'بنك']):
            return jsonify({
                'intent': 'collect_payment_data',
                'speak_text': 'تم استلام البيانات'
            })

        voice_mode_keywords = ['وضع الصوت', 'تفعيل الصوت', 'الصوت', 'صوتي',
                              'وضع صوتي', 'تفعيل الوضع الصوتي']
        if any(keyword in text_lower for keyword in voice_mode_keywords):
            return jsonify({
                'intent': 'enable_voice_mode',
                'speak_text': 'تم تفعيل وضع الصوت'
            })

        logout_keywords = ['تسجيل خروج', 'خروج', 'سجل خروج', 'أخرج', 'تسجيل الخروج',
                          'سجل الخروج', 'أريد الخروج', 'أبي أخرج', 'عايز أخرج', 'أبغى أخرج']
        if any(keyword in text_lower for keyword in logout_keywords):
            return jsonify({
                'intent': 'logout',
                'speak_text': 'جاري تسجيل الخروج'
            })

        settings_keywords = ['الإعدادات', 'إعدادات', 'الضبط', 'ضبط', 'الخيارات', 'خيارات',
                           'اذهب للإعدادات', 'افتح الإعدادات', 'عرض الإعدادات', 'الإعدادات إيش',
                           'شو الإعدادات', 'إيش الإعدادات']
        if any(keyword in text_lower for keyword in settings_keywords):
            return jsonify({
                'intent': 'settings',
                'speak_text': 'جاري فتح الإعدادات'
            })

        complete_order_keywords = ['تأكيد', 'أكيد', 'تمام', 'نعم', 'إتمام', 'أكمل', 'تأكيد الطلب',
                                  'تأكيد الشراء', 'أكيد الطلب', 'أكيد الشراء', 'إتمام الطلب', 'إتمام الشراء']
        if any(keyword in text_lower for keyword in complete_order_keywords):
            return jsonify({
                'intent': 'complete_order',
                'speak_text': 'جاري إتمام الطلب'
            })
        
        else:
            return jsonify({
                'intent': 'unknown',
                'message': 'لم أفهم الأمر، يرجى المحاولة مرة أخرى',
                'speak_text': 'لم أفهم الأمر، يرجى المحاولة مرة أخرى'
            })
    
    except Exception as e:
        return jsonify({
            'intent': 'error',
            'message': f'خطأ في المعالجة: {str(e)}',
            'speak_text': 'حدث خطأ أثناء معالجة الطلب'
        }), 500

def _generate_speak_text(intent: str, entities: dict) -> str:
    speak_texts = {
        'search': 'جاري البحث',
        'add_to_cart': 'تمت إضافة المنتج للسلة',
        'view_cart': 'جاري عرض السلة',
        'checkout': 'جاري إتمام عملية الشراء',
        'navigate_to_account': 'جاري الانتقال إلى الحساب',
        'add_address': 'سأساعدك في إضافة عنوان جديد',
        'add_payment_method': 'سأساعدك في إضافة طريقة دفع جديدة',
        'delete_order': 'جاري حذف الطلب',
        'read_description': 'جاري قراءة الوصف',
        'view_products': 'جاري عرض المنتجات',
        'remove_from_cart': 'جاري حذف المنتج من السلة',
        'logout': 'جاري تسجيل الخروج',
        'settings': 'جاري فتح الإعدادات',
        'complete_order': 'جاري إتمام الطلب',
    }
    return speak_texts.get(intent, 'تم استلام الأمر')

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'message': 'الخادم يعمل بشكل طبيعي'})

@app.route('/auth/register', methods=['POST'])
def register():
    try:
        if not request.is_json:
            return jsonify({
                'success': False,
                'message': 'يجب إرسال البيانات بصيغة JSON',
                'speak_text': 'خطأ في تنسيق البيانات'
            }), 400
        
        data = request.json
        name = data.get('name', '').strip()
        email = data.get('email', '').strip()
        phone = data.get('phone', '').strip()
        password = data.get('password', '')
        
        # Validation
        if not name or not email or not phone or not password:
            return jsonify({
                'success': False,
                'message': 'جميع الحقول مطلوبة',
                'speak_text': 'يرجى ملء جميع الحقول'
            }), 400
        
        if len(password) < 6:
            return jsonify({
                'success': False,
                'message': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                'speak_text': 'كلمة المرور قصيرة جداً'
            }), 400
        
        # Check if user already exists
        conn = db.get_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT id FROM users WHERE email = ? OR phone = ?', (email, phone))
        existing_user = cursor.fetchone()
        
        if existing_user:
            conn.close()
            return jsonify({
                'success': False,
                'message': 'البريد الإلكتروني أو رقم الهاتف موجود بالفعل',
                'speak_text': 'المستخدم موجود بالفعل'
            }), 400
        
        # Hash password
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        # Insert user
        cursor.execute('''
            INSERT INTO users (name, email, phone, password_hash)
            VALUES (?, ?, ?, ?)
        ''', (name, email, phone, password_hash))
        
        user_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'user_id': user_id,
            'message': 'تم إنشاء الحساب بنجاح',
            'speak_text': 'تم إنشاء الحساب بنجاح'
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'خطأ في الخادم: {str(e)}',
            'speak_text': 'حدث خطأ أثناء إنشاء الحساب'
        }), 500

@app.route('/auth/login', methods=['POST'])
def login():
    try:
        if not request.is_json:
            return jsonify({
                'success': False,
                'message': 'يجب إرسال البيانات بصيغة JSON',
                'speak_text': 'خطأ في تنسيق البيانات'
            }), 400
        
        data = request.json
        identifier = data.get('identifier', '').strip()  # يمكن أن يكون email أو phone
        password = data.get('password', '')
        
        if not identifier or not password:
            return jsonify({
                'success': False,
                'message': 'المعرف وكلمة المرور مطلوبان',
                'speak_text': 'يرجى إدخال البيانات المطلوبة'
            }), 400
        
        # Hash password
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        # Check user
        conn = db.get_connection()
        cursor = conn.cursor()
        
        # التحقق من أن identifier هو email أو phone
        if '@' in identifier:
            # email
            cursor.execute('''
                SELECT id, name, email, phone FROM users 
                WHERE email = ? AND password_hash = ?
            ''', (identifier, password_hash))
        else:
            # phone
            cursor.execute('''
                SELECT id, name, email, phone FROM users 
                WHERE phone = ? AND password_hash = ?
            ''', (identifier, password_hash))
        
        user_data = cursor.fetchone()
        conn.close()
        
        if user_data:
            return jsonify({
                'success': True,
                'user_id': user_data[0],
                'name': user_data[1],
                'email': user_data[2],
                'phone': user_data[3],
                'message': 'تم تسجيل الدخول بنجاح',
                'speak_text': 'تم تسجيل الدخول بنجاح'
            })
        else:
            return jsonify({
                'success': False,
                'message': 'البريد الإلكتروني أو رقم الهاتف أو كلمة المرور غير صحيحة',
                'speak_text': 'بيانات الدخول غير صحيحة'
            }), 401
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'خطأ في الخادم: {str(e)}',
            'speak_text': 'حدث خطأ أثناء تسجيل الدخول'
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
