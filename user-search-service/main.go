package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	"strconv"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
	"github.com/rs/cors"
)

// Configuración de la base de datos PostgreSQL  🚀
const (
	POSTGRESQL_HOST     = "aws-0-us-west-1.pooler.supabase.com"
	POSTGRESQL_PORT     = 6543
	POSTGRESQL_DATABASE = "postgres"
	POSTGRESQL_USER     = "postgres.imfqyzgimtercyyqeqof"
	POSTGRESQL_PASSWORD = "1997Guallaba"
)

var db *sql.DB

// Estructura que representa a un usuario
type User struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

// Inicializar la base de datos desde variables de entorno
func initDB() {
	// Cargar variables desde .env
	err := godotenv.Load()
	if err != nil {
		log.Fatal("❌ Error al cargar el archivo .env")
	}

	// Leer variables de entorno
	host := os.Getenv("POSTGRESQL_HOST")
	portStr := os.Getenv("POSTGRESQL_PORT")
	user := os.Getenv("POSTGRESQL_USER")
	password := os.Getenv("POSTGRESQL_PASSWORD")
	dbname := os.Getenv("POSTGRESQL_DATABASE")

	// Convertir el puerto a entero
	port, err := strconv.Atoi(portStr)
	if err != nil {
		log.Fatal("Puerto inválido:", err)
	}

	// Crear cadena de conexión
	connStr := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname,
	)

	// Conectar a la base de datos
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal("Error al conectar a la base de datos:", err)
	}

	err = db.Ping()
	if err != nil {
		log.Fatal("Error al hacer ping a la base de datos:", err)
	}

	fmt.Println("✅ Conectado a PostgreSQL exitosamente")
}

// Función SOAP que busca un usuario por su nombre
func getUserByUsernameSOAP(w http.ResponseWriter, r *http.Request) {
	// Obtener el nombre de usuario de la solicitud SOAP
	username := r.URL.Query().Get("username")
	if username == "" {
		http.Error(w, "El nombre de usuario es obligatorio", http.StatusBadRequest)
		return
	}

	// Consultar la base de datos
	var user User
	err := db.QueryRow("SELECT id, username FROM \"user\" WHERE username = $1", username).Scan(&user.ID, &user.Username)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error al consultar la base de datos: %s", err), http.StatusInternalServerError)
		return
	}

	// Crear el mensaje SOAP de respuesta
	soapResponse := fmt.Sprintf(`
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
			xmlns:web="http://www.example.org/webservice">
			<soapenv:Header/>
			<soapenv:Body>
				<web:getUserByUsernameResponse>
					<web:id>%s</web:id>
					<web:username>%s</web:username>
				</web:getUserByUsernameResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	`, user.ID, user.Username)

	// Establecer el encabezado de respuesta como XML
	w.Header().Set("Content-Type", "text/xml")
	w.Write([]byte(soapResponse))
}

func main() {
	// Inicializar la base de datos
	initDB()

	// Crear un enrutador para el servidor SOAP
	r := mux.NewRouter()

	// Ruta para consultar un usuario por su nombre
	r.HandleFunc("/user/soap", getUserByUsernameSOAP).Methods("GET")

	// Configurar CORS
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"http://3.227.120.143:8080"}, // Origen permitido (el servidor de la interfaz gráfica)
		AllowedMethods:   []string{"GET", "POST"},
		AllowedHeaders:   []string{"Content-Type"},
		AllowCredentials: true,
	})

	// Aplicar CORS a las rutas
	handler := c.Handler(r)

	// Iniciar el servidor HTTP en todas las interfaces
	fmt.Println("Iniciando servidor SOAP en el puerto 5016...")
	log.Fatal(http.ListenAndServe("0.0.0.0:5016", handler))
}
