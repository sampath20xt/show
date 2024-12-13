import json
import os
import time
import streamlit as st
from streamlit_pdf_viewer import pdf_viewer
from streamlit import session_state as ss
from PreProcessFile import pre_process, image_pdf
from Formatter import formatText
from Extractor import Extract
from Config import Config
from main import process
from DisplayOutput import display_json
from pymongo import MongoClient
from demo2 import generate_questions

# Establish a connection to the MongoDB database
try:
    mongo_client = MongoClient("mongodb+srv://Pranay:Pranay%409671610@pdfextraction.mj0vgph.mongodb.net/")
    db = mongo_client["DocumentProcessor"]
    collection = db['users']
except Exception as e:
    print(f"Error connecting to MongoDB: {e}")
    st.error("Error connecting to MongoDB")

# Initialize session states
if 'current_user' not in ss:
    ss['current_user'] = ""
if 'hit_count' not in ss:
    ss['hit_count'] = ""
if 'logged_in' not in ss:
    ss['logged_in'] = False
if 'auth_mode' not in ss:
    ss['auth_mode'] = "Login"


# Function to handle login
def login_page():
    try:
        st.markdown("<div style='background-color:#f5f5f5;padding:20px;border-radius:10px;'>", unsafe_allow_html=True)
        st.header(":key: Login to Your Account")
        with st.form("login_form"):
            usermail = st.text_input("Usermail", placeholder="Enter your email")
            password = st.text_input("Password", type="password", placeholder="Enter your password")
            login = st.form_submit_button("Login")
            if login:
                if not usermail or not password:
                    st.error(":warning: Usermail and password are required")
                else:
                    user_data = db["users"].find_one({"usermail": str(usermail), "password": str(password)})
                    if user_data:
                        ss['logged_in'] = True
                        ss['current_user'] = usermail
                        ss['hit_count'] = user_data['hits']
                        st.success(":white_check_mark: Login successful! Redirecting...")
                        st.rerun()
                    else:
                        st.error(":x: Invalid username or password")
        st.markdown("</div>", unsafe_allow_html=True)
    except Exception as e:
        print(f"Error in login page: {e}")
        st.error("Error in login page")


# Function to update hit count
def update_hit_count(hitcount):
    print("New hit count value: ", hitcount)
    try:
        usermail = ss['current_user']
        user_data = db["users"].find_one({"usermail": str(usermail)})
        if user_data:
            filtered = {"usermail": usermail}
            updated = {"$set": {"hits": int(hitcount)}}
            result = collection.update_one(filtered, updated)
            if result.modified_count == 1:
                print("count is updated in database")
                return {"Success": "hit count updated"}
    except Exception as e:
        print(f"Error updating hit count: {e}")
        st.error("Error updating hit count")


# Function to process file
def processFile():
    try:
        st.title(Config.PAGE_TITLE)
        st.markdown(
            """
                <style>
                %s
                </style>
                """ % open("style.css").read(),
            unsafe_allow_html=True
        )
        uploadedFile = st.file_uploader("Select a file to process", type=['png', 'jpg', 'jpeg', 'pdf'])
        progress_bar = st.progress(0)
        # Create a placeholder for status updates
        status_placeholder = st.empty()
        # Check if a file has been uploaded
        if uploadedFile is not None:
            file_name = uploadedFile.name
            file_extension = file_name.split(".")[-1]
            filePath = os.path.join(Config.FOLDER, file_name)
            with open(filePath, "wb") as f:
                f.write(uploadedFile.getvalue())
            progress_bar.progress(10)  # 10% progress
            status_placeholder.write(":green[File uploaded successfully!..]")
            start_time = time.time()
            col1, col2 = st.columns(2)
            # processedText = ""
            hit_count = 0

            with col1:
                pdf_viewer(filePath)

            with col2:
                if file_extension == 'pdf':
                    progress_bar.progress(20)  # 20% progress
                    status_placeholder.write(":orange[Detecting Text...]")
                    pdfPath = pre_process(filePath)
                    doclingText = process(pdfPath)
                    print(doclingText)
                    progress_bar.progress(40)  # 40% progress
                    # processedText += formatText(doclingText)
                    status_placeholder.write(":green[Done with Text Extraction]")

                elif file_extension in ['png', 'jpg', 'jpeg']:
                    status_placeholder.write(":orange[Detecting Text...]")
                    st.image(filePath)
                    pdfPath = image_pdf(filePath)
                    doclingText = process(pdfPath)
                    progress_bar.progress(40)  # 40% progress
                    # processedText += formatText(doclingText)
                    status_placeholder.write(":green[Done with Text Extraction]")

                status_placeholder.write(":orange[Extracting Information...]")
                output = formatText(doclingText)
                opening_brace_index = output.find('{')
                # Extract the content starting from the opening brace '{'
                if opening_brace_index != -1:
                    data = output[opening_brace_index:].replace("```", "")
                else:
                    print("Opening brace '{' not found in the JSON data.")
                progress_bar.progress(80)
                data = json.loads(data)
                print(data)
                display_json(data)
                # st.text(output)
                print("past hits are : ", ss['hit_count'])
                hit_count += 1
                if hit_count is not None:
                    updated_count = int(ss['hit_count']) + 1
                else:
                    updated_count = hit_count
                ss['hit_count'] = str(updated_count)
                print("Updated Count : ", updated_count)
                update_hit_count(updated_count)
                progress_bar.progress(100)  # 100% progress
                status_placeholder.write(":green[Done with File Processing]")
                status_placeholder.write(f":green[Finished in..] : {round(time.time() - start_time, 2)} in sec "
                                         ":heavy_check_mark:")
        else:
            st.write("Please upload a file to process.")
    except Exception as e:
        print(f"Error processing file: {e}")
        st.error("Error processing file")


# Main function
def main():
    try:
        st.set_page_config(
            page_title=Config.PAGE_TITLE,
            layout="wide"
        )
        if ss['logged_in']:
            processFile()
        else:
            if ss['auth_mode'] == "Login":
                login_page()

    except Exception as e:
        print(f"Error in main function: {e}")
        st.error("Error in main function")


if __name__ == '__main__':
    main()
