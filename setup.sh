#!/bin/bash

# Script de instalación automática del servidor RFID
# Autor: Sistema automatizado
# Fecha: 2024

echo "=========================================="
echo "  INSTALACIÓN SERVIDOR RFID"
echo "=========================================="

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 1. Crear directorio del proyecto
print_status "Creando directorio del proyecto..."
mkdir -p servidor_rfid
cd servidor_rfid

# 2. Verificar Python
print_status "Verificando instalación de Python..."
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    print_status "Python3 encontrado: $(python3 --version)"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    print_status "Python encontrado: $(python --version)"
else
    print_error "Python no está instalado. Por favor instala Python 3.7 o superior."
    exit 1
fi

# 3. Crear entorno virtual
print_status "Creando entorno virtual..."
$PYTHON_CMD -m venv venv

# 4. Activar entorno virtual
print_status "Activando entorno virtual..."
source venv/bin/activate

# 5. Actualizar pip
print_status "Actualizando pip..."
pip install --upgrade pip

# 6. Instalar dependencias
print_status "Instalando Flask, SQLAlchemy y CORS..."
pip install flask flask_sqlalchemy flask_cors

# 7. Crear requirements.txt
print_status "Creando requirements.txt..."
cat > requirements.txt << 'EOF'
Flask==3.0.0
Flask-SQLAlchemy==3.1.1
Flask-CORS==4.0.0
Werkzeug==3.0.1
EOF

# 8. Crear models.py
print_status "Creando models.py..."
cat > models.py << 'EOF'
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class Usuario(db.Model):
    __tablename__ = "usuarios"
    
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(120), nullable=False)
    rol = db.Column(db.String(50), nullable=False)
    uid = db.Column(db.String(50), unique=True, nullable=False)
    
    def to_dict(self):
        return {
            "id": self.id,
            "nombre": self.nombre,
            "rol": self.rol,
            "uid": self.uid
        }
    
    def __repr__(self):
        return f'<Usuario {self.nombre} - {self.rol}>'
EOF

# 9. Crear app.py (CORREGIDO)
print_status "Creando app.py..."
cat > app.py << 'EOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
from models import db, Usuario
import json

app = Flask(__name__)

# Configuración base de datos SQLite
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///database.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)
CORS(app)

# Crear tablas si no existen
with app.app_context():
    db.create_all()
    print("Base de datos inicializada correctamente")

@app.route("/")
def home():
    return jsonify({
        "status": "OK",
        "message": "Servidor RFID funcionando",
        "endpoints": ["/registrar", "/validar", "/usuarios"]
    })

# --------------------------
# API: Registrar usuario
# --------------------------
@app.route("/registrar", methods=["POST"])
def registrar():
    data = request.json
    print(f"Datos recibidos para registro: {data}")
    
    try:
        # Verificar si el UID ya existe
        existe = Usuario.query.filter_by(uid=data["uid"]).first()
        if existe:
            return jsonify({
                "status": "ERROR", 
                "msg": "El UID ya está registrado"
            }), 400
        
        # Crear nuevo usuario
        nuevo = Usuario(
            id=data["id"],
            nombre=data["nombre"],
            rol=data["rol"],
            uid=data["uid"]
        )
        
        db.session.add(nuevo)
        db.session.commit()
        
        print(f"Usuario registrado: {nuevo.nombre}")
        return jsonify({
            "status": "OK", 
            "msg": "Usuario registrado exitosamente",
            "usuario": nuevo.to_dict()
        }), 201
        
    except KeyError as e:
        return jsonify({
            "status": "ERROR", 
            "msg": f"Falta el campo: {str(e)}"
        }), 400
    except Exception as e:
        db.session.rollback()
        print(f"Error al registrar: {str(e)}")
        return jsonify({
            "status": "ERROR", 
            "msg": str(e)
        }), 500

# ---------------------------------
# API: Validar tarjeta RFID (ESP32)
# ---------------------------------
@app.route("/validar", methods=["POST"])
def validar():
    data = request.json
    print(f"Datos recibidos para validación: {data}")
    
    try:
        id_tarjeta = data["id"]
        uid_esp = data["uid"]
        
        # Buscar usuario por ID
        usuario = Usuario.query.filter_by(id=id_tarjeta).first()
        
        if usuario:
            if usuario.uid == uid_esp:
                print(f"Acceso autorizado: {usuario.nombre}")
                return jsonify({
                    "status": "OK",
                    "msg": "Acceso autorizado",
                    "nombre": usuario.nombre,
                    "rol": usuario.rol
                }), 200
            else:
                print(f"UID no coincide para ID {id_tarjeta}")
                return jsonify({
                    "status": "ERROR",
                    "msg": "UID no coincide"
                }), 403
        else:
            print(f"Usuario no encontrado: ID {id_tarjeta}")
            return jsonify({
                "status": "ERROR",
                "msg": "Usuario no registrado"
            }), 404
            
    except KeyError as e:
        return jsonify({
            "status": "ERROR", 
            "msg": f"Falta el campo: {str(e)}"
        }), 400
    except Exception as e:
        print(f"Error en validación: {str(e)}")
        return jsonify({
            "status": "ERROR", 
            "msg": str(e)
        }), 500

# ---------------------------------
# API: Listar todos los usuarios
# ---------------------------------
@app.route("/usuarios", methods=["GET"])
def listar_usuarios():
    try:
        usuarios = Usuario.query.all()
        return jsonify({
            "status": "OK",
            "total": len(usuarios),
            "usuarios": [u.to_dict() for u in usuarios]
        }), 200
    except Exception as e:
        return jsonify({
            "status": "ERROR",
            "msg": str(e)
        }), 500

# ---------------------------------
# API: Eliminar usuario
# ---------------------------------
@app.route("/eliminar/<int:id>", methods=["DELETE"])
def eliminar_usuario(id):
    try:
        usuario = Usuario.query.get(id)
        if usuario:
            db.session.delete(usuario)
            db.session.commit()
            return jsonify({
                "status": "OK",
                "msg": f"Usuario {usuario.nombre} eliminado"
            }), 200
        else:
            return jsonify({
                "status": "ERROR",
                "msg": "Usuario no encontrado"
            }), 404
    except Exception as e:
        db.session.rollback()
        return jsonify({
            "status": "ERROR",
            "msg": str(e)
        }), 500

if __name__ == "__main__":
    print("\n" + "="*50)
    print("  SERVIDOR RFID INICIADO")
    print("="*50)
    print(f"  URL: http://0.0.0.0:5000")
    print(f"  Endpoints disponibles:")
    print(f"    - POST /registrar")
    print(f"    - POST /validar")
    print(f"    - GET  /usuarios")
    print(f"    - DELETE /eliminar/<id>")
    print("="*50 + "\n")
    
    app.run(debug=True, host="0.0.0.0", port=5000)
EOF

# 10. Crear README.md
print_status "Creando README.md..."
cat > README.md << 'EOF'
# Servidor RFID

Sistema de control de acceso con tarjetas RFID usando ESP32 y Flask.

## Instalación
```bash
# Activar entorno virtual
source venv/bin/activate  # Linux/macOS
# o
venv\Scripts\activate.bat  # Windows

# Instalar dependencias
pip install -r requirements.txt
```

## Uso
```bash
# Iniciar servidor
python app.py
```

El servidor estará disponible en: `http://localhost:5000`

## Endpoints

### 1. Registrar Usuario
**POST** `/registrar`
```json
{
  "id": 1001,
  "nombre": "Erick Barrios",
  "rol": "admin",
  "uid": "233502"
}
```

### 2. Validar Usuario
**POST** `/validar`
```json
{
  "id": 1001,
  "uid": "233502"
}
```

### 3. Listar Usuarios
**GET** `/usuarios`

### 4. Eliminar Usuario
**DELETE** `/eliminar/<id>`

## Estructura del Proyecto
```
servidor_rfid/
├── app.py              # Aplicación principal
├── models.py           # Modelos de base de datos
├── database.db         # Base de datos SQLite (se genera automáticamente)
├── requirements.txt    # Dependencias
└── README.md          # Este archivo
```
EOF

# 11. Crear script de inicio
print_status "Creando script de inicio rápido..."
cat > start_server.sh << 'EOF'
#!/bin/bash
source venv/bin/activate
python app.py
EOF
chmod +x start_server.sh

# 12. Obtener IP local
print_status "Obteniendo IP local..."
if command -v ip &> /dev/null; then
    LOCAL_IP=$(ip route get 1 | awk '{print $7}' | head -1)
elif command -v ifconfig &> /dev/null; then
    LOCAL_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
else
    LOCAL_IP="localhost"
fi

# 13. Resumen final
echo ""
echo "=========================================="
print_status "INSTALACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "📁 Directorio: $(pwd)"
echo "🌐 IP Local: $LOCAL_IP"
echo "🔗 URL: http://$LOCAL_IP:5000"
echo ""
echo "Para iniciar el servidor:"
echo "  1. cd servidor_rfid"
echo "  2. source venv/bin/activate"
echo "  3. python app.py"
echo ""
echo "O simplemente ejecuta:"
echo "  ./start_server.sh"
echo ""
print_warning "Recuerda actualizar la IP en tus scripts ESP32:"
echo "  String serverURL = \"http://$LOCAL_IP:5000/registrar\";"
echo ""
echo "=========================================="
