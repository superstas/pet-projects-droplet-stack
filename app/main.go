package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

var (
	startTime = time.Now()
	port      = flag.Int("port", 9000, "Port to listen on")
	host      = flag.String("host", "0.0.0.0", "Host to bind to")
)

func main() {
	flag.Parse()

	// Setup graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)

	// Setup routes
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/metrics", handleMetrics)

	// Create server
	addr := fmt.Sprintf("%s:%d", *host, *port)
	server := &http.Server{
		Addr:         addr,
		Handler:      logMiddleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Example application starting on %s", addr)
		log.Printf("Endpoints available:")
		log.Printf("  - http://%s/", addr)
		log.Printf("  - http://%s/health", addr)
		log.Printf("  - http://%s/metrics", addr)
		log.Println()
		log.Println("Press Ctrl+C to stop")

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Error starting server: %v", err)
		}
	}()

	// Wait for shutdown signal
	<-sigChan
	log.Println("\nReceived shutdown signal, shutting down gracefully...")

	// Graceful shutdown
	if err := server.Close(); err != nil {
		log.Printf("Error during shutdown: %v", err)
	}

	log.Println("Server stopped")
}

// logMiddleware logs all HTTP requests
func logMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s - - [%s] \"%s %s %s\" %v",
			r.RemoteAddr,
			start.Format("02/Jan/2006:15:04:05 -0700"),
			r.Method,
			r.URL.Path,
			r.Proto,
			time.Since(start),
		)
	})
}

// handleIndex serves the main page
func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprint(w, indexHTML)
}

// handleHealth returns health check status
func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"healthy","service":"example-app","uptime":"%v"}`, time.Since(startTime))
}

// handleMetrics returns Prometheus metrics
func handleMetrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")

	uptime := time.Since(startTime).Seconds()

	fmt.Fprintf(w, `# HELP example_app_uptime_seconds Application uptime in seconds
# TYPE example_app_uptime_seconds gauge
example_app_uptime_seconds %.2f

# HELP example_app_info Application information
# TYPE example_app_info gauge
example_app_info{version="1.0.0",service="example-app"} 1

# HELP example_app_build_info Build information
# TYPE example_app_build_info gauge
example_app_build_info{go_version="%s"} 1
`, uptime, "go1.25")
}

const indexHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Example Application - Pet Projects Droplet Stack</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gradient-to-br from-purple-600 via-blue-600 to-indigo-700 min-h-screen">
    <div class="container mx-auto px-4 py-12">
        <div class="max-w-4xl mx-auto bg-white rounded-2xl shadow-2xl overflow-hidden">
            <!-- Header -->
            <div class="bg-gradient-to-r from-purple-600 to-indigo-600 px-8 py-12 text-white">
                <div class="flex items-center justify-center mb-4">
                    <svg class="w-16 h-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                    </svg>
                </div>
                <h1 class="text-4xl font-bold text-center mb-2">Example Application</h1>
                <p class="text-center text-purple-100 text-lg">Pet Projects Droplet Stack</p>
            </div>

            <!-- Content -->
            <div class="px-8 py-10">
                <!-- About Section -->
                <div class="mb-10">
                    <div class="flex items-center mb-4">
                        <svg class="w-6 h-6 text-purple-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        <h2 class="text-2xl font-bold text-gray-800">About This Application</h2>
                    </div>
                    <p class="text-gray-600 leading-relaxed">
                        This is a minimal example application built with <strong>Go</strong> (using only the standard library) 
                        and styled with <strong>Tailwind CSS</strong>. It serves as a reference implementation for the 
                        <a href="https://github.com/superstas/pet-projects-droplet-stack" class="text-purple-600 hover:text-purple-800 font-semibold underline" target="_blank">Pet Projects Droplet Stack</a>, 
                        demonstrating how to structure and deploy your own applications.
                    </p>
                </div>

                <!-- Endpoints Section -->
                <div class="mb-10">
                    <div class="flex items-center mb-4">
                        <svg class="w-6 h-6 text-blue-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                        </svg>
                        <h2 class="text-2xl font-bold text-gray-800">Available Endpoints</h2>
                    </div>
                    <div class="grid md:grid-cols-2 gap-4">
                        <a href="/" class="block p-4 bg-white border-2 border-purple-200 rounded-lg hover:border-purple-400 hover:shadow-md transition-all">
                            <div class="flex items-center mb-2">
                                <svg class="w-5 h-5 text-purple-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
                                </svg>
                                <code class="font-mono text-sm font-semibold text-gray-800">/</code>
                            </div>
                            <p class="text-sm text-gray-600">Main page (you are here)</p>
                        </a>
                        
                        <a href="/health" class="block p-4 bg-white border-2 border-green-200 rounded-lg hover:border-green-400 hover:shadow-md transition-all">
                            <div class="flex items-center mb-2">
                                <svg class="w-5 h-5 text-green-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                                </svg>
                                <code class="font-mono text-sm font-semibold text-gray-800">/health</code>
                            </div>
                            <p class="text-sm text-gray-600">Health check endpoint (JSON)</p>
                        </a>
                        
                        <a href="/metrics" class="block p-4 bg-white border-2 border-blue-200 rounded-lg hover:border-blue-400 hover:shadow-md transition-all">
                            <div class="flex items-center mb-2">
                                <svg class="w-5 h-5 text-blue-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                                </svg>
                                <code class="font-mono text-sm font-semibold text-gray-800">/metrics</code>
                            </div>
                            <p class="text-sm text-gray-600">Prometheus metrics</p>
                        </a>
                    </div>
                </div>

                <!-- Replace Section -->
                <div class="bg-gradient-to-r from-amber-50 to-orange-50 rounded-lg p-6 border-l-4 border-amber-500">
                    <div class="flex items-start">
                        <svg class="w-6 h-6 text-amber-600 mr-3 mt-1 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        <div>
                            <h3 class="text-lg font-bold text-gray-800 mb-2">Replace This Application</h3>
                            <p class="text-gray-700 mb-3">To deploy your own application:</p>
                            <ol class="list-decimal list-inside space-y-2 text-gray-700">
                                <li>Replace <code class="bg-white px-2 py-1 rounded text-sm">main.go</code> with your application code</li>
                                <li>Update <code class="bg-white px-2 py-1 rounded text-sm">start.sh</code> to build and run your app</li>
                                <li>Add your static files to the <code class="bg-white px-2 py-1 rounded text-sm">static/</code> directory</li>
                                <li>Create a release tag: <code class="bg-white px-2 py-1 rounded text-sm">git tag v1.0.0 && git push origin v1.0.0</code></li>
                            </ol>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Footer -->
            <div class="bg-gray-50 px-8 py-6 border-t border-gray-200">
                <div class="flex items-center justify-center text-gray-600 text-sm">
                    <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/>
                    </svg>
                    <span>Built with Go stdlib + Tailwind CSS</span>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
`
