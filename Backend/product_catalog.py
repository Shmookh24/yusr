from typing import List, Dict, Optional, Any
from .db import Database

class ProductCatalog:
    def __init__(self, db: Database):
        self.db = db
    
    def get_categories(self) -> List[Dict[str, Any]]:
        query = "SELECT id, name, name_ar, description, icon_path FROM categories ORDER BY name_ar"
        return self.db.execute_query(query)
    
    def search_products(self, query: str = "", category_id: Optional[int] = None, page: int = 1, per_page: int = 20) -> Dict[str, Any]:
        offset = (page - 1) * per_page
        conditions = []
        params = []
        
        if query:
            conditions.append("(name_ar LIKE ? OR description_ar LIKE ? OR name LIKE ?)")
            search_term = f"%{query}%"
            params.extend([search_term, search_term, search_term])
        
        if category_id:
            conditions.append("category_id = ?")
            params.append(category_id)
        
        where_clause = " AND ".join(conditions) if conditions else "1=1"
        
        count_query = f"SELECT COUNT(*) as total FROM products WHERE {where_clause}"
        total = self.db.execute_query(count_query, tuple(params))[0]['total']
        
        query_sql = f"""
            SELECT p.*, c.name_ar as category_name_ar
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE {where_clause}
            ORDER BY p.created_at DESC
            LIMIT ? OFFSET ?
        """
        params.extend([per_page, offset])
        
        products = self.db.execute_query(query_sql, tuple(params))
        
        return {
            'products': products,
            'total': total,
            'page': page,
            'per_page': per_page,
            'total_pages': (total + per_page - 1) // per_page
        }
    
    def get_product(self, product_id: int) -> Optional[Dict[str, Any]]:
        query = """
            SELECT p.*, c.name_ar as category_name_ar
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE p.id = ?
        """
        results = self.db.execute_query(query, (product_id,))
        return results[0] if results else None
    
    def generate_audio_description(self, product: Dict[str, Any]) -> str:
        name = product.get('name_ar', product.get('name', ''))
        description = product.get('description_ar', product.get('description', ''))
        price = product.get('price', 0)
        category = product.get('category_name_ar', '')
        
        audio_desc = f"المنتج: {name}. "
        if category:
            audio_desc += f"الفئة: {category}. "
        audio_desc += f"السعر: {price} ريال. "
        if description:
            audio_desc += f"الوصف: {description}. "
        
        stock = product.get('stock', 0)
        if stock > 0:
            audio_desc += f"متوفر في المخزون: {stock} قطعة."
        else:
            audio_desc += "غير متوفر حالياً."
        
        return audio_desc

