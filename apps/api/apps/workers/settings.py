import os

from django.conf import settings


# How long (in seconds) should the worker sleep between task lookups?
SLEEP = getattr(settings, 'WORKERS_SLEEP', 5)

# How many logs to keep in admin
KEEP = getattr(settings, 'WORKERS_KEEP', 100)


def pool_processes():
    """
    Number of worker processes, from WORKERS_PROCESSES. None (absent, empty or 0) lets multiprocessing use one
    process per CPU, each re-importing Django: bound it where memory is limited.
    """
    valeur = os.environ.get('WORKERS_PROCESSES', '')
    return int(valeur) if valeur not in ('', '0') else None
