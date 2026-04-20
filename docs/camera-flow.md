# Camera-Assisted Plate Recognition

1. Flutter opens the device camera.
2. Operator captures a vehicle image.
3. The image is sent to `POST /api/camera/anpr/recognize/`.
4. Django stores the image and runs:
   - OpenCV preprocessing
   - Tesseract OCR
   - Plate candidate extraction
5. The API returns:
   - detected plate
   - OCR confidence
   - candidate plates
   - raw OCR text
6. Flutter shows the suggested plate for human confirmation.
7. Operator can:
   - accept the plate
   - edit the plate
   - enter the plate manually if OCR fails
8. The confirmed plate is then used for entry or exit workflow.

## Audit Expectations

- Store every uploaded image
- Keep the raw OCR text
- Keep the operator-confirmed plate in the session

