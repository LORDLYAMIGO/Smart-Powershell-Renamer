# Smart Powershell Filerenamer (PowerShell)

A simple interactive PowerShell script that uses a generative LLM (by default Google Gemini via the Generative Language API) to suggest descriptive, filesystem-safe filenames for all files in a folder — then previews and optionally applies the renames.


## Features
- Collects filenames in a folder and sends them to an LLM with your custom instruction (e.g., "Make filenames descriptive and professional").
- Requests a JSON array of new filenames (without extensions) to ensure predictable parsing.
- Previews the proposed renames and asks for confirmation before applying changes.
- Sanitizes suggested names to remove invalid filesystem characters and prevents overwriting existing files.

## Requirements
- Windows PowerShell (the script uses standard PowerShell cmdlets)
- curl available in the system PATH
- A valid Google Generative Language API key (set in the script)
  - Can be modified to LLM of your choice.

## Usage
1. Set your API key in the script:
   $ApiKey = "YOUR_REAL_API_KEY"
2. Run the script in PowerShell.
3. When prompted:
   - Enter the folder path containing files to rename.
   - Enter a rename prompt (e.g., "Make filenames descriptive and professional").
4. Review the LLM-proposed filenames shown in order.
5. Confirm (Y) to apply the renames or cancel.



<img width="661" height="833" alt="Screenshot 2025-10-31 132335" src="https://github.com/user-attachments/assets/aa9b1721-53f6-4641-a89c-91168a1eb52a" />

<img width="1227" height="721" alt="File Names Before" src="https://github.com/user-attachments/assets/9cf2ce48-f57e-4df6-bc0b-c01dbc918499" />
<img width="837" height="691" alt="Script Usage" src="https://github.com/user-attachments/assets/9047cb99-d2aa-4329-a605-197da19df033" />
<img width="724" height="709" alt="Script Output" src="https://github.com/user-attachments/assets/1883a0bd-a7b7-4ef8-bb01-b255e2743bb6" />
<img width="786" height="148" alt="Script Output 2" src="https://github.com/user-attachments/assets/957fe910-0455-41fc-83d3-ce43ffb9d05f" />
<img width="614" height="799" alt="File Names After" src="https://github.com/user-attachments/assets/12e8e9cd-ca70-46ec-99e0-faaa67217068" />


## How it works (brief)
- The script enumerates files in the provided folder.
- It builds a prompt containing the user's instruction and the current filenames, asking the LLM to return a JSON array of new base filenames (same order, no extensions).
- The response is parsed, validated (count and JSON), previewed, sanitized, and then applied after user confirmation.

## Response format requirement
The script instructs the LLM to respond ONLY with a valid JSON array of strings (no file extensions), e.g.:
["Invoice_2025-09", "ProjectPlan_Backup", "Photo_Vacation_01"]

This strict format reduces parsing errors and accidental output noise.

## Safety notes
- The script will not overwrite existing files; suggested renames that collide with existing filenames are skipped.
- It sanitizes filenames to remove characters invalid on Windows/Unix (\, /, :, *, ?, ", <, >, |).
- Always review the preview before confirming.

## Troubleshooting
- If curl is not found, install curl or run on a system with curl available.
- If the LLM response cannot be parsed as JSON, inspect the raw output printed by the script (it removes common Markdown fences before parsing).
- Ensure your API key is set and valid for the endpoint used.

## License
MIT License
