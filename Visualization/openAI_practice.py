import openai
import streamlit as st

openai.api_key = "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"
#it will not valid

prompt = st.text_input("Enter a prompt")
if prompt:
   response = openai.Completion.create(
       engine="gpt-3.5-turbo-instruct",
       prompt=prompt,
       max_tokens=100,
       n=1,
       stop=None,
       temperature=0.7,
   )
   st.write(response.choices[0].text)

#streamlit run /opt/anaconda3/lib/python3.11/site-packages/ipykernel_launcher.py   















