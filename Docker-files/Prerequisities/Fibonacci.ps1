# PowerShell Script to Generate Fibonacci Sequence or a Specific Fibonacci Number

param (
    [int]$position = 0 # Position of the Fibonacci number to retrieve. Defaults to 0 for indefinite generation.
)

function Get-FibonacciNumber {
    param (
        [int]$n
    )
    
    $fib0 = 0
    $fib1 = 1

    for ($i = 0; $i -lt $n; $i++) {
        $temp = $fib0
        $fib0 = $fib1
        $fib1 = $temp + $fib1
    }

    return $fib0
}

if ($position -eq 0) {
    Write-Output "Generating Fibonacci sequence indefinitely. Press Ctrl+C to stop."
    $i = 0
    while ($true) {
        $fibNum = Get-FibonacciNumber -n $i
        Write-Output $fibNum
        $i++
        Start-Sleep -Milliseconds 500 # Slow down output
    }
} else {
    $fibNum = Get-FibonacciNumber -n $position
    Write-Output "Fibonacci number at position $position is $fibNum"
}
