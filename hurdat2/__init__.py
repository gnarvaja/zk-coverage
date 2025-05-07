import logging
import os

logging.basicConfig(
    level=getattr(logging, os.environ.get("LOG_LEVEL", "INFO")),
    format="%(asctime)s %(levelname)-8s [%(name)s] [%(thread)d] %(message)s",
)
