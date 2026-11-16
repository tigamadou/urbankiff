from django.core.cache import cache
from hashlib import sha256


def generate_cache_key(view_name, params):
    """Generate a unique cache key using the view name and request params."""
    key_base = f"{view_name}_{sha256(str(params).encode()).hexdigest()}"
    return key_base


def get_or_set_cache(key, timeout, fetch_func, *args, **kwargs):
    """Retrieve data from cache or fetch and store it."""
    data = cache.get(key)
    if data is None:
        data = fetch_func(*args, **kwargs)
        cache.set(key, data, timeout)
    return data
