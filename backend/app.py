import os
import json
import threading
import uuid
from flask import Flask, request, jsonify
from flask_cors import CORS
from google import genai
from google.genai import types
from dotenv import load_dotenv
import time 


app = Flask(__name__)
CORS(app)

load_dotenv()
api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("Warning: GEMINI_API_KEY not set. Check environment variables.")
    client = None 
else:
    try:
        client = genai.Client(api_key=api_key)
    except Exception as e:
        print(f"Error initializing Gemini client: {e}")
        client = None 

job_manager = {}

output_schema = types.Schema(
    type=types.Type.ARRAY,
    items=types.Schema(
        type=types.Type.OBJECT,
        properties={
            "sender": types.Schema(type=types.Type.STRING),
            "subject": types.Schema(type=types.Type.STRING),
            "summary": types.Schema(
                type=types.Type.ARRAY,
                items=types.Schema(type=types.Type.STRING),
            ),
        },
        required=["sender", "subject", "summary"]
    )
)



def run_summarization_job(job_id, email_data):
    """The actual long-running task to be executed in a separate thread."""
    print(f"Job {job_id}: Starting summarization...")
    job_manager[job_id]["progress"] = 10 
    
    PROMPT_INSTRUCTIONS = f"""
    You are an expert email summarization system.
    For each email separated by '---':
    1. Extract the sender
    2. Extract the subject
    3. Summarize in 3-4 bullet points (main action/request/deadline)

    Return a JSON array of objects with fields sender, subject, summary.

    EMAIL DATA:
    ---
    {email_data}
    ---
    """
    
    try:
        time.sleep(1) 
        job_manager[job_id]["progress"] = 30 

        if not client:
            
            raise Exception("Gemini client is not initialized. Please set GEMINI_API_KEY.")

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=PROMPT_INSTRUCTIONS,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=output_schema,
            ),
        )

        job_manager[job_id]["progress"] = 75 # Simulate API response received
        parsed_json = json.loads(response.text)
        
        # Final status update
        job_manager[job_id]["results"] = parsed_json
        job_manager[job_id]["progress"] = 100
        job_manager[job_id]["status"] = "completed"
        print(f"Job {job_id}: Completed successfully.")

    except Exception as e:
        # CRITICAL FIX: Ensure the job manager entry exists before updating status
        if job_id in job_manager:
            job_manager[job_id]["error"] = str(e)
            job_manager[job_id]["status"] = "failed"
            job_manager[job_id]["progress"] = 100
        print(f"Job {job_id}: Failed with error: {e}")

# --- API ENDPOINTS ---

@app.route("/submit_job", methods=["POST"])
def submit_job():
    """Receives file and starts the summarization job asynchronously."""
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]
    # Added error handling for decode
    try:
        email_data = file.read().decode("utf-8")
    except UnicodeDecodeError:
        return jsonify({"error": "File decoding failed. Ensure it's a valid UTF-8 text file."}), 400
    
    job_id = str(uuid.uuid4())
    job_manager[job_id] = {"status": "processing", "progress": 0, "results": None, "error": None}
    
   
    thread = threading.Thread(target=run_summarization_job, args=(job_id, email_data))
    thread.start()
    
    return jsonify({"job_id": job_id}), 202 # 202 Accepted status

@app.route("/status/<job_id>", methods=["GET"])
def get_status(job_id):
    """Allows the frontend to poll for the current progress and final results."""
    if job_id not in job_manager:
        return jsonify({"error": "Job not found"}), 404
        
    job = job_manager[job_id]
    
    if job["status"] == "completed":
        results = job["results"]
        del job_manager[job_id] 
        return jsonify({
            "status": "completed",
            "progress": 100,
            "results": results
        }), 200
        
    elif job["status"] == "failed":
        error_msg = job["error"]
        del job_manager[job_id] 
        return jsonify({
            "status": "failed",
            "progress": 100,
            "error": error_msg
        }), 500 # Use 500 to clearly signal a server-side error to Flutter
        
    else:
        return jsonify({
            "status": "processing",
            "progress": job["progress"]
        }), 200

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
