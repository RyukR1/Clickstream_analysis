import os
from pathlib import Path

__version__ = "2.0.0"

# Auto-configure JAVA_HOME if not already set or invalid
_java_candidates = [
    os.environ.get("JAVA_HOME", ""),
    str(Path.home() / ".local/share/jvm/temurin-17"),
    "/usr/lib/jvm/java-17-openjdk-amd64",
    "/usr/lib/jvm/java-11-openjdk-amd64",
    "/usr/lib/jvm/default-java",
]

for candidate in _java_candidates:
    if candidate and Path(candidate).is_dir():
        java_bin = Path(candidate) / "bin" / "java"
        if java_bin.exists():
            os.environ["JAVA_HOME"] = candidate
            current_path = os.environ.get("PATH", "")
            bin_dir = str(Path(candidate) / "bin")
            if bin_dir not in current_path:
                os.environ["PATH"] = f"{bin_dir}:{current_path}"
            break
