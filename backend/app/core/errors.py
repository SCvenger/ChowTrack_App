# pyrefly: ignore [missing-import]
from fastapi import Request, HTTPException
# pyrefly: ignore [missing-import]
from fastapi.responses import JSONResponse


class ChowTrackException(Exception):
    def __init__(self, status_code: int, message: str, detail: str = None):
        self.status_code = status_code
        self.message = message
        self.detail = detail
        super().__init__(self.message)


async def global_exception_handler(request: Request, exc: Exception):
    
    if isinstance(exc, ChowTrackException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "error": exc.message,
                "detail": exc.detail,
            }
        )
    
    if isinstance(exc, HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "error": exc.detail,
                "detail": "HTTPException",
            }
        )
    
    print(f"[ERROR NO CONTROLADO] {type(exc).__name__}: {str(exc)}")
    
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Ocurrió un problema en nuestros servidores.",
            "detail": str(exc) if True else None,  
        }
    )