import argparse
import json
from datetime import UTC, datetime
from pathlib import Path


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate AboutMetadata.json")

    parser.add_argument("--sha", required=True)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--repository_url", required=True)
    parser.add_argument("--output", required=True)

    return parser.parse_args()


def main() -> None:
    args = parse_arguments()

    repository_url = args.repository_url.rstrip("/")
    copyright_value = f"DAWN {datetime.now(UTC).year}"

    metadata = {
        "copyright": copyright_value,
        "license": "GNU GENERAL PUBLIC LICENSE",
        "commit": {
            "sha": args.sha,
            "reference": args.reference,
            "url": f"{repository_url}/commit/{args.sha}",
        },
        "privacyPolicyURL": repository_url,
        "termsOfUseURL": repository_url,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
