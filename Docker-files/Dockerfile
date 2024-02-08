# Use the PowerShell image
FROM mcr.microsoft.com/powershell

# Copy the Fibonacci script into the container
COPY Fibonacci.ps1 /Fibonacci.ps1

# When the container starts, run the script
ENTRYPOINT ["pwsh", "-File", "/Fibonacci.ps1"]
