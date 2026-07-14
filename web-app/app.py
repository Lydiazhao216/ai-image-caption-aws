"""
Image Captioning App — Flask web application

Handles image upload, stores the file in S3, triggers async captioning
and thumbnail generation (via Lambda + EventBridge, see ../lambda-annotation
and ../lambda-thumbnail), and displays a gallery of uploaded images with
their AI-generated captions.

Configuration is read from environment variables — no secrets are
hardcoded. See .env.example for the variables this app expects.
"""

import os
import boto3
import mysql.connector
from flask import Flask, request, render_template
from werkzeug.utils import secure_filename
import google.generativeai as genai
import base64
from io import BytesIO

# ------------------ Configuration (from environment variables) ------------------

GOOGLE_API_KEY = os.environ["GOOGLE_API_KEY"]
genai.configure(api_key=GOOGLE_API_KEY)
model = genai.GenerativeModel(model_name="gemini-2.5-flash-preview-04-17")

S3_BUCKET = os.environ["S3_BUCKET"]
S3_REGION = os.environ.get("S3_REGION", "us-east-1")

DB_HOST = os.environ["DB_HOST"]
DB_NAME = os.environ.get("DB_NAME", "image_caption_db")
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif"}

app = Flask(__name__)

# ------------------ Utility Functions ------------------

def generate_image_caption(image_data):
    try:
        encoded_image = base64.b64encode(image_data).decode("utf-8")
        response = model.generate_content([
            {"mime_type": "image/jpeg", "data": encoded_image},
            "Caption this image."
        ])
        return response.text if response.text else "No caption generated."
    except Exception as e:
        return f"Error: {str(e)}"

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

def get_s3_client():
    return boto3.client("s3", region_name=S3_REGION)

def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASSWORD
        )
        return connection
    except mysql.connector.Error as err:
        print("Error connecting to database:", err)
        return None

# ------------------ Flask Routes ------------------

@app.route("/")
def upload_form():
    return render_template("index.html")

@app.route("/upload", methods=["GET", "POST"])
def upload_image():
    if request.method == "POST":
        if "file" not in request.files or request.files["file"].filename == "":
            return render_template("upload.html", error="No file selected")

        file = request.files["file"]
        if not allowed_file(file.filename):
            return render_template("upload.html", error="Invalid file type")

        filename = secure_filename(file.filename)
        file_data = file.read()
        s3_key = f"uploads/{filename}"
        thumbnail_key = f"uploads/thumbnails/{filename}"

        try:
            s3 = get_s3_client()
            s3.upload_fileobj(BytesIO(file_data), S3_BUCKET, s3_key)
        except Exception as e:
            return render_template("upload.html", error=f"S3 Upload Error: {str(e)}")

        caption = generate_image_caption(file_data)

        try:
            connection = get_db_connection()
            if connection is None:
                return render_template("upload.html", error="Database Error: Unable to connect to the database.")
            cursor = connection.cursor()
            cursor.execute(
                "INSERT INTO captions (image_key, caption) VALUES (%s, %s)",
                (s3_key, caption),
            )
            connection.commit()
            connection.close()
        except Exception as e:
            return render_template("upload.html", error=f"Database Error: {str(e)}")

        encoded_image = base64.b64encode(file_data).decode("utf-8")
        file_url = f"https://{S3_BUCKET}.s3.{S3_REGION}.amazonaws.com/{s3_key}"
        thumbnail_url = get_s3_client().generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": thumbnail_key},
            ExpiresIn=3600
        )

        return render_template("upload.html", image_data=encoded_image, file_url=file_url, caption=caption, thumbnail_url=thumbnail_url)

    return render_template("upload.html")

@app.route("/gallery")
def gallery():
    try:
        connection = get_db_connection()
        if connection is None:
            return render_template("gallery.html", error="Database Error: Unable to connect to the database.")
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT image_key, caption FROM captions ORDER BY uploaded_at DESC")
        results = cursor.fetchall()
        connection.close()

        images_with_captions = [
            {
                "url": get_s3_client().generate_presigned_url(
                    "get_object",
                    Params={"Bucket": S3_BUCKET, "Key": row["image_key"]},
                    ExpiresIn=3600,
                ),
                "thumbnail_url": get_s3_client().generate_presigned_url(
                    "get_object",
                    Params={"Bucket": S3_BUCKET, "Key": row["image_key"].replace("uploads/", "uploads/thumbnails/")},
                    ExpiresIn=3600,
                ),
                "caption": row["caption"],
            }
            for row in results
        ]
        return render_template("gallery.html", images=images_with_captions)

    except Exception as e:
        return render_template("gallery.html", error=f"Database Error: {str(e)}")

# ------------------ Run App ------------------

if __name__ == "__main__":
    # NOTE: debug=True is convenient for local development but should never
    # be used in a real production deployment (it exposes stack traces to
    # anyone who can trigger an error). A production run would use a WSGI
    # server such as Gunicorn with debug disabled.
    app.run(debug=True, host="0.0.0.0", port=5000)
