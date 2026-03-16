import sys
from pathlib import Path

# make lambda packages importable from tests/
sys.path.insert(0, str(Path(__file__).parent.parent))
