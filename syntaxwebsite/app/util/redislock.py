from app.extensions import redis_controller
import time
import redis

# DEPRECATED - DO NOT USE ANYMORE - USE REDIS_LOCKS INSTEAD
def acquire_lock(lock_name, acquire_timeout=10, lock_timeout=60):
    """Acquires a Redis lock with a specific name."""
    identifier = str(time.time()) 
    end_time = time.time() + acquire_timeout

    while time.time() < end_time:
        if redis_controller.set(lock_name, identifier, nx=True, ex=lock_timeout):
            return identifier
        time.sleep(0.001)

    return None

def release_lock(lock_name, identifier):
    """Releases a Redis lock with a specific name and identifier."""
    if redis_controller.get(lock_name) == identifier:
        redis_controller.delete(lock_name)
        return True
    return False

