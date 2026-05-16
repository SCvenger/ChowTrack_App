# pyrefly: ignore [missing-import]
from fastapi import Request, HTTPException
# pyrefly: ignore [missing-import]
from fastapi.responses import JSONResponse

class ChowTrackException(Exception):
    def __init__(self, status_code: int, message: str, detail: str = None):
        self.status_code = status_code
        self.message = message
        self.detail = detail

# Asegúrate de que el nombre esté exactamente así, todo en minúsculas y con guiones bajos
async def global_exception_handler(request: Request, exc: Exception):
    if isinstance(exc, ChowTrackException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "error": exc.message,
                "technical_detail": exc.detail
            }
        )
    
    if isinstance(exc, HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "error": exc.detail,
                "technical_detail": "HTTPValidationError"
            }
        )
    
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Ocurrió un problema en nuestros servidores. Inténtalo más tarde.",
            "technical_detail": str(exc)
        }
    )