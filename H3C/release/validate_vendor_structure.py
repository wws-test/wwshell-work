import json
import sys
import jsonschema

def validate_json_structure(json_file_path, schema_file_path):
    """
    Validates a JSON file against a JSON schema file.

    Args:
        json_file_path (str): The path to the JSON file containing the data (directory structure).
        schema_file_path (str): The path to the JSON schema file.

    Returns:
        int: 0 if validation is successful, 1 if validation fails, 2 if there's an error reading files or arguments.
    """
    try:
        # Read JSON data
        with open(json_file_path, 'r') as f:
            json_data = json.load(f)
        print(f"Successfully read JSON data from {json_file_path}")

        # Read JSON schema
        with open(schema_file_path, 'r') as f:
            json_schema = json.load(f)
        print(f"Successfully read JSON schema from {schema_file_path}")

        # Perform validation
        jsonschema.validate(instance=json_data, schema=json_schema)

        print("JSON validation successful!")
        return 0 # Success

    except FileNotFoundError:
        print(f"Error: File not found. Check paths: {json_file_path} or {schema_file_path}", file=sys.stderr)
        return 2 # File error
    except json.JSONDecodeError:
        print(f"Error: Could not decode JSON from {json_file_path} or {schema_file_path}. Check file format.", file=sys.stderr)
        return 2 # JSON format error
    except jsonschema.exceptions.ValidationError as e:
        print("JSON validation failed:", file=sys.stderr)
        print(f"Error details: {e.message}", file=sys.stderr)
        # You might want to print more details for complex schemas
        # print(e.path)
        # print(e.schema_path)
        return 1 # Validation failure
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        return 2 # Other errors

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python validate_script.py <json_file_path> <schema_file_path>", file=sys.stderr)
        sys.exit(2) # Incorrect arguments

    json_file = sys.argv[1]
    schema_file = sys.argv[2]

    exit_code = validate_json_structure(json_file, schema_file)
    sys.exit(exit_code)