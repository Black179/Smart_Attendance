#!/usr/bin/env python3
"""
Test script for the FastAPI backend endpoints
"""
import requests
import json
from datetime import date

BASE_URL = "http://localhost:8000"

def test_enroll():
    """Test student enrollment"""
    print("Testing student enrollment...")
    
    data = {
        "student_name": "John Doe",
        "class_name": "Class A"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/enroll", json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_mark_attendance():
    """Test marking attendance"""
    print("\nTesting mark attendance...")
    
    data = {
        "student_name": "John Doe",
        "class_name": "Class A",
        "date": date.today().isoformat(),
        "status": "present"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/mark_attendance", json=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_upload_endpoint():
    """Test upload endpoint availability"""
    print("\nTesting upload endpoint...")
    
    try:
        response = requests.get(f"{BASE_URL}/list_uploads")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    print("=== FastAPI Backend Test ===")
    
    # Test if server is running
    try:
        response = requests.get(f"{BASE_URL}/docs")
        print("✅ FastAPI server is running")
    except:
        print("❌ FastAPI server is not running. Please start it first.")
        return
    
    # Run tests
    tests = [
        test_enroll,
        test_mark_attendance,
        test_upload_endpoint
    ]
    
    passed = 0
    for test in tests:
        if test():
            passed += 1
            print("✅ PASSED")
        else:
            print("❌ FAILED")
    
    print(f"\n=== Test Results: {passed}/{len(tests)} tests passed ===")

if __name__ == "__main__":
    main()



