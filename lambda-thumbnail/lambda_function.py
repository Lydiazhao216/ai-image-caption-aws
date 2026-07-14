import boto3
import os
from PIL import Image
import io

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        # EventBridge 包装后的S3事件结构：字段在 event['detail'] 下
        # （原始S3直接触发的事件结构是 event['Records'][0]['s3']，两者不同）
        bucket = event['detail']['bucket']['name']
        key = event['detail']['object']['key']
        
        # 只处理 uploads/ 路径下的原始图片，忽略 uploads/thumbnails/ 路径下的图片，避免循环触发
        # （EventBridge规则本身已经用 prefix: uploads/ 过滤过一次，这里是双重保险）
        if key.startswith('uploads/thumbnails/'):
            print("Skipping thumbnail image.")
            return
        
        # 缩略图目标路径：uploads/thumbnails/文件名（与报告描述的目录结构一致）
        thumbnail_key = f"uploads/thumbnails/{os.path.basename(key)}"

        # 去重检查：如果同名缩略图已存在，直接跳过，避免重复计算
        try:
            s3.head_object(Bucket=bucket, Key=thumbnail_key)
            print(f"Thumbnail already exists at {thumbnail_key}, skipping.")
            return {
                'statusCode': 200,
                'body': f'Thumbnail already exists at {thumbnail_key}'
            }
        except s3.exceptions.ClientError:
            # head_object 在文件不存在时会抛出404错误，属于预期情况，继续往下生成缩略图
            pass

        # 下载原图
        response = s3.get_object(Bucket=bucket, Key=key)
        image_data = response['Body'].read()
        
        # 处理为缩略图
        image = Image.open(io.BytesIO(image_data))
        image.thumbnail((128, 128))  # 可自定义缩略图大小
        buffer = io.BytesIO()
        image.save(buffer, format='JPEG')
        buffer.seek(0)
        
        # 上传缩略图
        s3.put_object(Bucket=bucket, Key=thumbnail_key, Body=buffer, ContentType='image/jpeg')
        
        return {
            'statusCode': 200,
            'body': f'Thumbnail saved to {thumbnail_key}'
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'body': str(e)
        }
