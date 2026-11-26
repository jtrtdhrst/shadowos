const statusButton = document.querySelector("#check-status");
const statusMessage = document.querySelector("#status-message");

statusButton?.addEventListener("click", () => {
  const address = window.location.host;
  statusMessage.textContent = address
    ? `Strona działa pod adresem ${address}.`
    : "Strona działa poprawnie.";
});
