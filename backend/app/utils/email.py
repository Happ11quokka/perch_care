import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.config import get_settings


def send_reset_code_email(to_email: str, code: str) -> None:
    """Send a password reset code via Gmail SMTP."""
    settings = get_settings()

    if not settings.smtp_user or not settings.smtp_password:
        print(f"[DEV] SMTP not configured. Reset code for {to_email}: {code}")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "[Perch Care] 비밀번호 재설정 코드"
    msg["From"] = settings.smtp_user
    msg["To"] = to_email

    text = f"비밀번호 재설정 코드: {code}\n\n이 코드는 10분간 유효합니다."
    html = f"""\
    <div style="font-family: 'Pretendard', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
      <h2 style="color: #1A1A1A; margin-bottom: 8px;">비밀번호 재설정</h2>
      <p style="color: #97928A; font-size: 14px; margin-bottom: 24px;">
        아래 인증 코드를 앱에 입력해 주세요.
      </p>
      <div style="background: linear-gradient(to right, #FF9A42, #FF7C2A); border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px;">
        <span style="font-size: 32px; font-weight: 700; color: white; letter-spacing: 8px;">{code}</span>
      </div>
      <p style="color: #97928A; font-size: 12px;">
        이 코드는 10분간 유효합니다.<br>
        본인이 요청하지 않았다면 이 이메일을 무시해 주세요.
      </p>
    </div>
    """

    msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port) as server:
        server.starttls()
        server.login(settings.smtp_user, settings.smtp_password)
        server.sendmail(settings.smtp_user, to_email, msg.as_string())
