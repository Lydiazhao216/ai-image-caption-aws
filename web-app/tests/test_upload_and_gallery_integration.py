from io import BytesIO
from unittest.mock import MagicMock, patch
from conftest import app_module


@patch.object(app_module, "get_s3_client")
@patch.object(app_module, "get_db_connection")
@patch.object(app_module, "generate_image_caption")
def test_upload_success_writes_to_s3_and_db(
    mock_caption, mock_db_conn, mock_s3_client, client
):
    mock_caption.return_value = "A cat sitting on a windowsill."

    mock_cursor = MagicMock()
    mock_connection = MagicMock()
    mock_connection.cursor.return_value = mock_cursor
    mock_db_conn.return_value = mock_connection

    mock_s3 = MagicMock()
    mock_s3.generate_presigned_url.return_value = "https://example.com/presigned"
    mock_s3_client.return_value = mock_s3

    data = {"file": (BytesIO(b"fake image bytes"), "cat.jpg")}
    response = client.post("/upload", data=data, content_type="multipart/form-data")

    assert response.status_code == 200
    # The image bytes should have been uploaded to S3 under uploads/
    mock_s3.upload_fileobj.assert_called_once()
    args, kwargs = mock_s3.upload_fileobj.call_args
    assert args[2] == "uploads/cat.jpg"
    # The caption should have been written to the database
    mock_cursor.execute.assert_called_once()
    insert_args = mock_cursor.execute.call_args[0][1]
    assert insert_args == ("uploads/cat.jpg", "A cat sitting on a windowsill.")
    mock_connection.commit.assert_called_once()


@patch.object(app_module, "get_db_connection")
def test_gallery_handles_db_connection_failure_gracefully(mock_db_conn, client):
    mock_db_conn.return_value = None
    response = client.get("/gallery")
    assert response.status_code == 200
    assert b"Database Error" in response.data
