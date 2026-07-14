from conftest import app_module


def test_allowed_file_accepts_valid_extensions():
    assert app_module.allowed_file("photo.jpg") is True
    assert app_module.allowed_file("photo.jpeg") is True
    assert app_module.allowed_file("photo.png") is True
    assert app_module.allowed_file("photo.gif") is True


def test_allowed_file_rejects_invalid_extensions():
    assert app_module.allowed_file("document.pdf") is False
    assert app_module.allowed_file("script.py") is False


def test_allowed_file_rejects_no_extension():
    assert app_module.allowed_file("noextension") is False


def test_allowed_file_is_case_insensitive():
    assert app_module.allowed_file("PHOTO.JPG") is True
