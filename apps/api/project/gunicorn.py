import os

bind = '0.0.0.0:8000'
workers = int(os.environ.get('WEB_CONCURRENCY', 2))
worker_tmp_dir = '/tmp'
accesslog = '-'
errorlog = '-'
# Les envois de fichiers vers le stockage peuvent depasser les 30 s par defaut.
timeout = 120
graceful_timeout = 20
