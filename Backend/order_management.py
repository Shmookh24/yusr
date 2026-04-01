from typing import List, Dict, Optional, Any
from .db import Database

class OrderManagement:
    def __init__(self, db: Database):
        self.db = db
    
    def get_cart(self, user_id: int) -> List[Dict[str, Any]]:
        query = """
            SELECT ci.*, p.name_ar, p.name, p.price, p.image_paths
            FROM cart_items ci
            JOIN products p ON ci.product_id = p.id
            WHERE ci.user_id = ?
            ORDER BY ci.created_at DESC
        """
        return self.db.execute_query(query, (user_id,))
    
    def add_to_cart(self, user_id: int, product_id: int, quantity: int = 1) -> Dict[str, Any]:
        existing = self.db.execute_query(
            "SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?",
            (user_id, product_id)
        )
        
        if existing:
            new_quantity = existing[0]['quantity'] + quantity
            self.db.execute_update(
                "UPDATE cart_items SET quantity = ? WHERE user_id = ? AND product_id = ?",
                (new_quantity, user_id, product_id)
            )
        else:
            self.db.execute_update(
                "INSERT INTO cart_items (user_id, product_id, quantity) VALUES (?, ?, ?)",
                (user_id, product_id, quantity)
            )
        
        return {'success': True, 'message': f'تمت إضافة {quantity} قطعة إلى السلة'}
    
    def update_cart_item(self, user_id: int, product_id: int, quantity: int) -> Dict[str, Any]:
        if quantity <= 0:
            self.db.execute_update(
                "DELETE FROM cart_items WHERE user_id = ? AND product_id = ?",
                (user_id, product_id)
            )
            return {'success': True, 'message': 'تم حذف المنتج من السلة'}
        else:
            self.db.execute_update(
                "UPDATE cart_items SET quantity = ? WHERE user_id = ? AND product_id = ?",
                (quantity, user_id, product_id)
            )
            return {'success': True, 'message': f'تم تحديث الكمية إلى {quantity}'}
    
    def clear_cart(self, user_id: int):
        self.db.execute_update("DELETE FROM cart_items WHERE user_id = ?", (user_id,))
    
    def checkout(self, user_id: int, payment_method: str, address: str) -> Dict[str, Any]:
        cart_items = self.get_cart(user_id)
        if not cart_items:
            return {'success': False, 'message': 'السلة فارغة'}
        
        total_amount = sum(item['price'] * item['quantity'] for item in cart_items)
        
        order_id = self.db.execute_update(
            """INSERT INTO orders (user_id, total_amount, payment_method, address, status)
               VALUES (?, ?, ?, ?, 'pending')""",
            (user_id, total_amount, payment_method, address)
        )
        
        for item in cart_items:
            self.db.execute_update(
                """INSERT INTO order_items (order_id, product_id, quantity, price)
                   VALUES (?, ?, ?, ?)""",
                (order_id, item['product_id'], item['quantity'], item['price'])
            )
        
        self.clear_cart(user_id)
        
        return {
            'success': True,
            'order_id': order_id,
            'total_amount': total_amount,
            'message': f'تم إنشاء الطلب بنجاح. رقم الطلب: {order_id}. المبلغ الإجمالي: {total_amount} ريال'
        }
    
    def get_order_status(self, order_id: int, user_id: int) -> Optional[Dict[str, Any]]:
        query = """
            SELECT o.*, 
                   GROUP_CONCAT(p.name_ar || ' (' || oi.quantity || ')') as items_summary
            FROM orders o
            LEFT JOIN order_items oi ON o.id = oi.order_id
            LEFT JOIN products p ON oi.product_id = p.id
            WHERE o.id = ? AND o.user_id = ?
            GROUP BY o.id
        """
        results = self.db.execute_query(query, (order_id, user_id))
        return results[0] if results else None
    
    def request_return(self, order_id: int, user_id: int, reason: str) -> Dict[str, Any]:
        order = self.get_order_status(order_id, user_id)
        if not order:
            return {'success': False, 'message': 'الطلب غير موجود'}
        
        return_id = self.db.execute_update(
            """INSERT INTO returns (order_id, user_id, reason, status)
               VALUES (?, ?, ?, 'pending')""",
            (order_id, user_id, reason)
        )
        
        return {
            'success': True,
            'return_id': return_id,
            'message': 'تم تقديم طلب الاسترجاع بنجاح. سيتم مراجعته قريباً'
        }
    
    def get_user_orders(self, user_id: int) -> List[Dict[str, Any]]:
        query = """
            SELECT o.*, 
                   GROUP_CONCAT(p.name_ar || ' (' || oi.quantity || ')') as items_summary
            FROM orders o
            LEFT JOIN order_items oi ON o.id = oi.order_id
            LEFT JOIN products p ON oi.product_id = p.id
            WHERE o.user_id = ?
            GROUP BY o.id
            ORDER BY o.created_at DESC
        """
        return self.db.execute_query(query, (user_id,))

