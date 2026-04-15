from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.models.user import User
from app.models.notification import Notification
from app.schemas.notification import NotificationResponse

router = APIRouter()

@router.get("/", response_model=List[NotificationResponse])
def get_notifications(
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO: Contexto del Negocio
) -> Any:
    """Obtiene todas las notificaciones del usuario para el NEGOCIO ACTUAL, ordenadas por la más reciente."""
    return db.query(Notification).filter(
        Notification.user_id == current_user.id,
        # 🔥 Asumimos que Notification tiene negocio_id. Si no lo tiene, debemos agregarlo al modelo.
        # Si NO tienes negocio_id en Notification, la lógica alternativa es filtrar por los objetos relacionados,
        # pero lo ideal y profesional es que cada notificación sepa a qué negocio pertenece.
        Notification.negocio_id == negocio_id 
    ).order_by(Notification.fecha_creacion.desc()).all()

@router.put("/{notif_id}/read", response_model=NotificationResponse)
def mark_as_read(
    notif_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
) -> Any:
    """Marca una notificación específica como leída en el negocio actual."""
    notif = db.query(Notification).filter(
        Notification.id == notif_id, 
        Notification.user_id == current_user.id,
        Notification.negocio_id == negocio_id # 🔥 SEGURIDAD DE CONTEXTO
    ).first()
    
    if not notif:
        raise HTTPException(status_code=404, detail="Notificación no encontrada en este negocio")
        
    notif.leida = True
    db.commit()
    db.refresh(notif)
    return notif

@router.put("/read-all")
def mark_all_as_read(
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
) -> Any:
    """Marca todas las notificaciones del usuario como leídas en el negocio actual."""
    db.query(Notification).filter(
        Notification.user_id == current_user.id, 
        Notification.negocio_id == negocio_id, # 🔥 SEGURIDAD DE CONTEXTO
        Notification.leida == False
    ).update({"leida": True})
    db.commit()
    return {"message": "Todas las notificaciones de este negocio fueron marcadas como leídas"}

@router.delete("/{notif_id}")
def delete_notification(
    notif_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
) -> Any:
    """Elimina una notificación del negocio actual."""
    notif = db.query(Notification).filter(
        Notification.id == notif_id, 
        Notification.user_id == current_user.id,
        Notification.negocio_id == negocio_id # 🔥 SEGURIDAD DE CONTEXTO
    ).first()
    
    if not notif:
        raise HTTPException(status_code=404, detail="Notificación no encontrada en este negocio")
        
    db.delete(notif)
    db.commit()
    return {"message": "Notificación eliminada"}