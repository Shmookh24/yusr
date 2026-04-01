import sqlite3
import os
from typing import Optional, List, Dict, Any
from datetime import datetime

class Database:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._ensure_db_directory()
        self._init_database()
    
    def _ensure_db_directory(self):
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
    
    def _init_database(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                phone TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                voice_passphrase TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                name_ar TEXT NOT NULL,
                description TEXT,
                icon_path TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                name_ar TEXT NOT NULL,
                description TEXT,
                description_ar TEXT,
                price REAL NOT NULL,
                category_id INTEGER,
                image_paths TEXT,
                audio_description TEXT,
                stock INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (category_id) REFERENCES categories(id)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS cart_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id),
                FOREIGN KEY (product_id) REFERENCES products(id),
                UNIQUE(user_id, product_id)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                total_amount REAL NOT NULL,
                payment_method TEXT NOT NULL,
                address TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS order_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                quantity INTEGER NOT NULL,
                price REAL NOT NULL,
                FOREIGN KEY (order_id) REFERENCES orders(id),
                FOREIGN KEY (product_id) REFERENCES products(id)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS returns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                reason TEXT,
                status TEXT DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (order_id) REFERENCES orders(id),
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_preferences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                preference_key TEXT NOT NULL,
                preference_value TEXT,
                FOREIGN KEY (user_id) REFERENCES users(id),
                UNIQUE(user_id, preference_key)
            )
        ''')
        
        conn.commit()
        conn.close()
        
        self._seed_initial_data()
    
    def _seed_initial_data(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('SELECT COUNT(*) FROM categories')
        if cursor.fetchone()[0] == 0:
            categories = [
                ('Electronics', 'إلكترونيات', 'Electronic devices and accessories', ''),
                ('Clothing', 'ملابس', 'Clothing and fashion items', ''),
                ('Food', 'طعام', 'Food and beverages', ''),
                ('Books', 'كتب', 'Books and reading materials', ''),
                ('Home', 'منزل', 'Home and kitchen items', '')
            ]
            cursor.executemany('INSERT INTO categories (name, name_ar, description, icon_path) VALUES (?, ?, ?, ?)', categories)
            
            products = [
                ('Smartphone', 'هاتف ذكي', 'Latest smartphone with advanced features', 'هاتف ذكي بمواصفات متقدمة', 2999.99, 1, '[]', None, 50),
                ('Laptop', 'حاسوب محمول', 'High-performance laptop', 'حاسوب محمول عالي الأداء', 5999.99, 1, '[]', None, 30),
                ('T-Shirt', 'قميص', 'Cotton t-shirt', 'قميص قطني', 99.99, 2, '[]', None, 100),
                ('Coffee', 'قهوة', 'Premium coffee beans', 'حبوب قهوة ممتازة', 149.99, 3, '[]', None, 200),
                ('Novel', 'رواية', 'Best-selling novel', 'رواية من الأكثر مبيعاً', 79.99, 4, '[]', None, 150)
            ]
            cursor.executemany('''
                INSERT INTO products (name, name_ar, description, description_ar, price, category_id, image_paths, audio_description, stock)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', products)
        
        conn.commit()
        conn.close()
    
    def get_connection(self):
        return sqlite3.connect(self.db_path)
    
    def execute_query(self, query: str, params: tuple = ()) -> List[Dict[str, Any]]:
        conn = self.get_connection()
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute(query, params)
        rows = cursor.fetchall()
        conn.close()
        return [dict(row) for row in rows]
    
    def execute_update(self, query: str, params: tuple = ()) -> int:
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, params)
        conn.commit()
        last_id = cursor.lastrowid
        conn.close()
        return last_id

