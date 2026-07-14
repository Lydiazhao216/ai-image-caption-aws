from io import BytesIO


def test_upload_get_shows_form(client):
    response = client.get("/upload")
    assert response.status_code == 200


def test_upload_post_no_file_selected(client):
    response = client.post("/upload", data={}, content_type="multipart/form-data")
    assert response.status_code == 200
    assert b"No file selected" in response.data


def test_upload_post_invalid_file_type(client):
    data = {
        "file": (BytesIO(b"not a real file"), "malware.exe"),
    }
    response = client.post("/upload", data=data, content_type="multipart/form-data")
    assert response.status_code == 200
    assert b"Invalid file type" in response.data
