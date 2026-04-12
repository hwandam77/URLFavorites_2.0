import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cardView", "listView", "cardButton", "listButton"]

  connect() {
    const savedMode = localStorage.getItem("urlf2_view_mode") || "card"
    if (savedMode === "list") {
      this.switchToList()
    } else {
      this.switchToCard()
    }
  }

  switchToCard() {
    this.cardViewTarget.classList.remove("hidden")
    this.listViewTarget.classList.add("hidden")
    this.updateButtonStates("card")
    localStorage.setItem("urlf2_view_mode", "card")
  }

  switchToList() {
    this.cardViewTarget.classList.add("hidden")
    this.listViewTarget.classList.remove("hidden")
    this.updateButtonStates("list")
    localStorage.setItem("urlf2_view_mode", "list")
  }

  updateButtonStates(activeMode) {
    const baseStyle = "padding:6px 12px;border-radius:6px;font-size:13px;font-weight:500;transition:all 0.15s;cursor:pointer;border:none;"
    const activeStyle = baseStyle + "background:var(--color-accent);color:#fff;"
    const inactiveStyle = baseStyle + "background:transparent;color:var(--color-text-muted);"

    if (activeMode === "card") {
      this.cardButtonTarget.style.cssText = activeStyle
      this.listButtonTarget.style.cssText = inactiveStyle
    } else {
      this.listButtonTarget.style.cssText = activeStyle
      this.cardButtonTarget.style.cssText = inactiveStyle
    }
  }
}
