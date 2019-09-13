# Racket Test Server

To test a Racket web server making many synchronous requests and performing under a hard deadline, I made this project. The program should accept a request on `/numbers` endpoint with various ?u parameter queries. The server should perform a GET request on each endpoint obtaining a json list of numbers (ex `{numbers: [1, 2, 3]}`), and then aggregate all the results. The application should always return a response under 500ms, even if it couldn't get any numbers.

## Running the example

The exercise can be run via `racket server.rkt`. To run with the GC logs and with incremental GC you can run `PLTSTDERR=debug PLT_INCREMENTAL_GC=1 racket challenge.rkt`.

An example request to the server looks like the following:

```
curl localhost:3000/numbers\?u=http://localhost:8090/primes\&u=http://localhost:8090/primes\&u=http://localhost:8090/primes\&u=http://localhost:8090/primes\&u=http://localhost:8090/primes\&u=http://localhost:8090/primes
```

Provided in the repository is a server written in Go that has various endpoints ("/primes", "fibo", "/odd", and "/rand") for testing the server. A random delay between 0 and 20ms is also included. If you have Go installed, you can run the number server via `go run numberserver.go`. 


## Benchmarking

For benchmarking the performance I used the tool vegeta: https://github.com/tsenart/vegeta . With vegeta installed you can perform a stress test with:

```
echo 'GET http://localhost:3000/numbers?u=http://localhost:8090/primes&u=http://localhost:8090/random' | vegeta attack -duration=5m -rate 100/1s | tee results.bin | vegeta plot > plot.html
```

changing -duration to make the test run for longer or shorter, and changing -rate to change the rate that the server is hit with requests. Opening plot.html shows a plot of the performance and `cat results.bin | vegeta report` will show a statistical summary of the results.
