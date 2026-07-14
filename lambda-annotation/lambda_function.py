import boto3
import base64
import json
import os
import pymysql
import requests

# 环境变量中设置这些值（下一步会讲）
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
DB_NAME = os.environ['DB_NAME']
GEMINI_API_KEY = os.environ['GEMINI_API_KEY']

def lambda_handler(event, context):
    try:
        # 1. 获取 S3 上传信息
        bucket = event['detail']['bucket']['name']
        key = event['detail']['object']['key']


        s3 = boto3.client('s3')
        obj = s3.get_object(Bucket=bucket, Key=key)
        image_bytes = obj['Body'].read()
        encoded_image = base64.b64encode(image_bytes).decode('utf-8')

        # 2. 调用 Gemini API（根据你的用法可微调）
        gemini_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-04-17:generateContent?key={GEMINI_API_KEY}"
        headers = {
            "Content-Type": "application/json"
        }
        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "inline_data": {
                                "mime_type": "image/jpeg",
                                "data": encoded_image
                            }
                        }
                    ]
                }
            ]
        }

        response = requests.post(gemini_url, headers=headers, json=payload)
        print("Gemini full response:", response.json())  # 🪵调试信息
        caption = response.json()['candidates'][0]['content']['parts'][0]['text']

        # 3. 写入 RDS 数据库
        connection = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )

        with connection.cursor() as cursor:
            sql = "INSERT INTO images (filename, caption) VALUES (%s, %s)"
            cursor.execute(sql, (key, caption))
            connection.commit()

        return {
            'statusCode': 200,
            'body': json.dumps(f'Caption added: {caption}')
        }

    except Exception as e:
        print("Exception occurred:", str(e))
        return {
            'statusCode': 500,
            'body': str(e)
        }
