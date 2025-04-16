import os
import pdf2image
import easyocr
import xml.etree.ElementTree as ET


def convert_pdf_to_images(pdf_path):
    """
    Converts a PDF file into images, with each page represented as an image.
    """
    print(f"Converting PDF '{pdf_path}' to images...")
    images = pdf2image.convert_from_path(pdf_path)
    return images


def extract_text_from_image(image):
    """
    Uses EasyOCR to extract text from an image.
    """
    print("Performing OCR on the image...")
    reader = easyocr.Reader(['en'])  # Set language to English
    ocr_results = reader.readtext(image)
    
    # Collect the text from OCR results
    extracted_text = "\n".join([text[1] for text in ocr_results])
    return extracted_text


def parse_resume_to_xml(resume_text):
    """
    Takes the extracted resume text and organizes it into an XML format.
    """
    root = ET.Element("Resume")

    # Split the text into individual lines
    lines = resume_text.splitlines()
    
    # Assuming the first line contains the name
    name = lines[0] if len(lines) > 0 else ""
    name_elem = ET.SubElement(root, "Name")
    name_elem.text = name.strip()

    # Assuming the second line contains contact information (email or phone)
    contact_info = lines[1] if len(lines) > 1 else ""
    contact_elem = ET.SubElement(root, "ContactInfo")
    contact_elem.text = contact_info.strip()

    # Try to extract Education and Work Experience
    education = []
    work_experience = []

    # Basic categorization based on keywords like 'Education' or 'Experience'
    section = None
    for line in lines[2:]:
        if "education" in line.lower():
            section = "Education"
        elif "work experience" in line.lower() or "experience" in line.lower():
            section = "WorkExperience"
        
        if section == "Education" and line.strip():
            education.append(line.strip())
        elif section == "WorkExperience" and line.strip():
            work_experience.append(line.strip())
    
    # Add Education section to XML
    education_elem = ET.SubElement(root, "Education")
    for edu in education:
        edu_elem = ET.SubElement(education_elem, "Entry")
        edu_elem.text = edu

    # Add Work Experience section to XML
    work_experience_elem = ET.SubElement(root, "WorkExperience")
    for work in work_experience:
        work_elem = ET.SubElement(work_experience_elem, "Entry")
        work_elem.text = work

    return root


def save_xml_to_file(xml_root, output_path):
    """
    Save the structured XML to a file.
    """
    tree = ET.ElementTree(xml_root)
    tree.write(output_path)


def process_resume(pdf_path, output_xml_path):
    """
    Main function that takes a PDF resume, extracts text using OCR, 
    parses it, and saves it as an XML file.
    """
    print(f"Processing resume from PDF: {pdf_path}")
    
    # Convert PDF to images
    images = convert_pdf_to_images(pdf_path)
    
    # Extract text from each page using OCR
    resume_text = ""
    for image in images:
        resume_text += extract_text_from_image(image)
    
    # Parse the extracted text and generate XML
    xml_root = parse_resume_to_xml(resume_text)

    # Save the parsed XML to a file
    save_xml_to_file(xml_root, output_xml_path)
    print(f"XML resume saved to: {output_xml_path}")


if __name__ == "__main__":
    # Path to the PDF resume and desired XML output file
    pdf_directory = "resumes/"
    pdf_filename = "resume.pdf"
    pdf_path = os.path.join(pdf_directory, pdf_filename)
    output_xml_path = os.path.join(pdf_directory, "resume_output.xml")

    # Process the resume
    process_resume(pdf_path, output_xml_path)