import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  copy(event) {
    const url = this.element.dataset.clipboardUrl || event.currentTarget.dataset.clipboardUrl
    if (!url) return

    navigator.clipboard.writeText(url).then(() => {
      this.showToast("URL이 복사되었습니다")
    }).catch(() => {
      // Fallback for older browsers
      this.fallbackCopy(url)
    })
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    try {
      document.execCommand("copy")
      this.showToast("URL이 복사되었습니다")
    } catch (err) {
      this.showToast("복사에 실패했습니다", "error")
    }
    document.body.removeChild(textarea)
  }

  showToast(message, type = "success") {
    // Remove existing toast
    const existing = document.querySelector("[data-toast]")
    if (existing) existing.remove()

    // Create toast element
    const toast = document.createElement("div")
    toast.dataset.toast = ""
    toast.style.cssText = `
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%);
      padding: 12px 24px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      z-index: 9999;
      animation: slideUp 0.3s ease-out;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      ${type === "success"
        ? "background: #166534; color: #fff;"
        : "background: #991b1b; color: #fff;"}
    `
    toast.textContent = message

    // Add animation styles
    const style = document.createElement("style")
    style.textContent = `
      @keyframes slideUp {
        from { opacity: 0; transform: translateX(-50%) translateY(10px); }
        to { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
    `
    document.head.appendChild(style)
    document.body.appendChild(toast)

    // Auto remove after 2 seconds
    setTimeout(() => {
      toast.style.opacity = "0"
      toast.style.transition = "opacity 0.3s"
      setTimeout(() => toast.remove(), 300)
    }, 2000)
  }
}
