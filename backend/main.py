from fastapi import FastAPI
app = FastAPI()
@app.get("/")
def home():
    return {"message": "its working!"} #تجربة عمل السيرفر في الرابط 

@app.post("/data")
def receive_data(data: dict):
    return data                  #جزء استقبال البيانات
