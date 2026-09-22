import os

import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)


def get_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
    )


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/db")
def db():
    try:
        with get_connection() as conn, conn.cursor() as cur:
            cur.execute("SELECT version(), now()")
            version, now = cur.fetchone()
        return jsonify(status="ok", postgres=version, server_time=str(now))
    except psycopg2.Error:
        return jsonify(status="error", detail="database unreachable"), 503