import os
import requests
import pdf2image
import easyocr
import xml.etree.ElementTree as ET


def download_from_google_drive(shareable_link, output_path):
    """
    Downloads a file from a Google Drive shareable link.
    """
    print("Downloading resume from Google Drive...")
    
    # Extract file ID from shareable link
    if "id=" in shareable_link:
        file_id = shareable_link.split("id=")[-1]
    elif "file/d/" in shareable_link:
        file_id = shareable_link.split("file/d/")[1].split("/")[0]
    else:
        raise ValueError("Invalid Google Drive link format.")

    # Construct direct download URL
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


def parse_resume_to_xml(resume_text):
    root = ET.Element("Resume")
    lines = resume_text.splitlines()
    
    name = lines[0] if lines else ""
    ET.SubElement(root, "Name").text = name.strip()

    contact = lines[1] if len(lines) > 1 else ""
    ET.SubElement(root, "ContactInfo").text = contact.strip()

    education, work_experience = [], []
    section = None

    for line in lines[2:]:
        lower = line.lower()
        if "education" in lower:
            section = "Education"
        elif "experience" in lower:
            section = "WorkExperience"

        if section == "Education":
            education.append(line.strip())
        elif section == "WorkExperience":
            work_experience.append(line.strip())

    edu_elem = ET.SubElement(root, "Education")
    for e in education:
        ET.SubElement(edu_elem, "Entry").text = e

    work_elem = ET.SubElement(root, "WorkExperience")
    for w in work_experience:
        ET.SubElement(work_elem, "Entry").text = w

    return root


def save_xml(xml_root, output_path):
    ET.ElementTree(xml_root).write(output_path)
    print(f"XML saved to: {output_path}")


def process_resume_from_drive(drive_link, download_dir):
    """
    Downloads a resume from Google Drive, processes it, and generates XML.
    """
    os.makedirs(download_dir, exist_ok=True)

    pdf_path = os.path.join(download_dir, "resume.pdf")
    xml_path = os.path.join(download_dir, "resume.xml")

    # Step 1: Download the file
    download_from_google_drive(drive_link, pdf_path)

    # Step 2: Convert to images
    images = convert_pdf_to_images(pdf_path)

    # Step 3: OCR
    full_text = ""
    for img in images:
        full_text += extract_text_from_image(img)

    # Step 4: Parse text to XML
    xml_root = parse_resume_to_xml(full_text)

    # Step 5: Save XML
    save_xml(xml_root, xml_path)


if __name__ == "__main__":
    # Replace this with the Google Drive shareable link
    drive_link = "https://drive.google.com/file/d/1yOURFILEIDHERE/view?usp=sharing"
    output_dir = "/resumes"

    process_resume_from_drive(drive_link, output_dir)
