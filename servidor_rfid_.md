mkdir servidor_rfid
cd servidor_rfid

3intalar Python

#crear entorno windows
python -m venv venv
venv\Scripts\actívate.bat

#crear entorno Linux 
python3 -m venv venv
source venv/bin/activate

#instalar flask y sqlarquemy
pip install flask flask_sqlalchemy flask_cors

#Estructura del proyecto 
servidor_rfid/
│
├── app.py
├── models.py
├── database.db  (se genera solo)
└── requirements.txt


nano models.py 

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

---------------------------------------------------------
nano app.py

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

@app.route("/")
def home():
    return "Servidor RFID funcionando"

# --------------------------
# API: Registrar usuario
# --------------------------
@app.route("/registrar", methods=["POST"])
def registrar():
    data = request.json

    try:
        nuevo = Usuario(
            id_usuario=data["id_usuario"],
            nombre=data["nombre"],
            rol=data["rol"],
            uid=data["uid"]
        )
        db.session.add(nuevo)
        db.session.commit()
        return jsonify({"status": "OK", "msg": "Usuario registrado"})

    except Exception as e:
        return jsonify({"status": "ERROR", "msg": str(e)})

# ---------------------------------
# API: Validar tarjeta RFID (ESP32)
# ---------------------------------
@app.route("/validar", methods=["POST"])
def validar():
    data = request.json

    # ESP32 envía:
    # { "uid": "...", "datos": "{id_usuario:..., nombre:..., rol:...}" }

    try:
        datos_tarjeta = json.loads(data["datos"])
        id_tarjeta = datos_tarjeta["id_usuario"]
        uid_esp = data["uid"]

        usuario = Usuario.query.filter_by(id_usuario=id_tarjeta).first()

        if usuario:
            if usuario.uid == uid_esp:
                return jsonify({
                    "status": "OK",
                    "nombre": usuario.nombre,
                    "rol": usuario.rol
                })
            else:
                return jsonify({"status": "INVALID_UID"})
        else:
            return jsonify({"status": "NO_REGISTRADO"})

    except Exception as e:
        return jsonify({"status": "ERROR", "msg": str(e)})

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)


---------------------------------------------------------

#iniciar server 
python app.py

#Ejemplo json
{
  "id": 1001,
  "nombre": "Erick Barrios",
  "rol": "admin",
  "uid": "233502"
}

#ejemplo ESP32

{
  "uid": "233502",
  "datos": "{\"id\":1001,\"nombre\":\"Erick\",\"rol\":\"admin\"}"
}
