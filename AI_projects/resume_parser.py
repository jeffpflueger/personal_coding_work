import os
import requests
import pdf2image
import easyocr
import json


def download_from_google_drive(shareable_link, output_path):
    print("Downloading resume from Google Drive...")
    
    if "id=" in shareable_link:
        file_id = shareable_link.split("id=")[-1]
    elif "file/d/" in shareable_link:
        file_id = shareable_link.split("file/d/")[1].split("/")[0]
    else:
        raise ValueError("Invalid Google Drive link format.")

    download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
    
    response = requests.get(download_url)
    if response.status_code != 200:
        raise Exception("Failed to download the file from Google Drive.")

    with open(output_path, 'wb') as f:
        f.write(response.content)
    
    print(f"File saved to {output_path}")


def convert_pdf_to_images(pdf_path):
    print(f"Converting PDF '{pdf_path}' to images...")
    return pdf2image.convert_from_path(pdf_path)


def extract_text_from_image(image):
    print("Performing OCR on the image...")
    reader = easyocr.Reader(['en'], gpu=False)
    ocr_results = reader.readtext(image)
    return "\n".join([text[1] for text in ocr_results])


def parse_resume_to_json(resume_text):
    lines = resume_text.splitlines()
    
    name = lines[0] if lines else ""
    contact = lines[1] if len(lines) > 1 else ""
    education, work_experience = [], []
    section = None

    for line in lines[2:]:
        lower = line.lower()
        if "education" in lower:
            section = "Education"
            continue
        elif "experience" in lower:
            section = "WorkExperience"
            continue

        if section == "Education" and line.strip():
            education.append({
                "institution": line.strip(),
                "area": "",
                "studyType": "",
                "startDate": "",
                "endDate": "",
                "gpa": "",
                "courses": []
            })

        elif section == "WorkExperience" and line.strip():
            work_experience.append({
                "company": line.strip(),
                "position": "",
                "website": "",
                "startDate": "",
                "endDate": "",
                "summary": "",
                "highlights": []
            })

    resume_json = {
        "basics": {
            "name": name.strip(),
            "email": "",  # You could try parsing email from contact info
            "phone": contact.strip(),
            "summary": "",
            "location": {},
            "profiles": []
        },
        "work": work_experience,
        "education": education,
        "skills": [],
        "projects": [],
        "certificates": [],
        "awards": [],
        "languages": [],
        "interests": [],
        "references": []
    }

    return resume_json


def save_json(json_data, output_path):
    with open(output_path, 'w') as f:
        json.dump(json_data, f, indent=2)
    print(f"JSON Resume saved to: {output_path}")


def process_resume_from_drive(drive_link, download_dir):
    os.makedirs(download_dir, exist_ok=True)

    pdf_path = os.path.join(download_dir, "resume.pdf")
    json_path = os.path.join(download_dir, "resume.json")

    download_from_google_drive(drive_link, pdf_path)

    images = convert_pdf_to_images(pdf_path)

    full_text = ""
    for img in images:
        full_text += extract_text_from_image(img) + "\n"

    resume_json = parse_resume_to_json(full_text)

    save_json(resume_json, json_path)


if __name__ == "__main__":
    drive_link = "https://drive.google.com/file/d/1yOURFILEIDHERE/view?usp=sharing"
    output_dir = "./resumes"

    process_resume_from_drive(drive_link, output_dir)
