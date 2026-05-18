-- ---------------------------------------------------------------------------
-- Setup: Se ejecuta de un tirón al cargar (SIN YIELDS AQUÍ)
-- ---------------------------------------------------------------------------
database.execute ([[
    CREATE TABLE IF NOT EXISTS users (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        email TEXT    NOT NULL UNIQUE,
        score REAL    NOT NULL DEFAULT 0
    )
]])

database.execute ("DELETE FROM users")
database.execute ("INSERT INTO users (name, email, score) VALUES (?, ?, ?)", {"Alice", "alice@example.com", 95.5})
database.execute ("INSERT INTO users (name, email, score) VALUES (?, ?, ?)", {"Bob",   "bob@example.com",   80.0})
database.execute ("INSERT INTO users (name, email, score) VALUES (?, ?, ?)", {"Eve",   "eve@example.com",   73.2})

-- ---------------------------------------------------------------------------
-- GET /hello
-- ---------------------------------------------------------------------------
server.route ("GET", "/hello", function (request, response)
    local message = "Hello from the bridge! Method: " .. request:get_method()
                 .. " | Agent: " .. (request:get_header("User-Agent") or "unknown")

    response:status     (200)
    response:header     ("Content-Type",   "text/plain; charset=utf-8")
    response:header     ("Content-Length",  #message)
    response:header     ("Connection",     "close")
    response:end_header ()
    response:body       (message)
    
    coroutine.yield() -- CORRECCIÓN: Notifica a C++ que la respuesta está lista
end)

-- ---------------------------------------------------------------------------
-- GET /users
-- ---------------------------------------------------------------------------
server.route ("GET", "/users", function (request, response)
    local body = ""
    local row  = database.query("SELECT id, name, email, score FROM users ORDER BY id")

    -- Procesamos todas las filas seguidas para armar el string
    while row:advance() do
        local id    = row:get_integer (1)
        local name  = row:get_string  (2)
        local email = row:get_string  (3)
        local score = row:get_real    (4)
        body = body .. id .. " | " .. name .. " | " .. email .. " | " .. score .. "\n"
    end

    response:status     (200)
    response:header     ("Content-Type",   "text/plain; charset=utf-8")
    response:header     ("Content-Length",  #body)
    response:header     ("Connection",     "close")
    response:end_header ()
    response:body       (body)
    
    coroutine.yield() -- CORRECCIÓN: Rendimos el control al terminar de armar la respuesta
end)

-- ---------------------------------------------------------------------------
-- GET /users/<id>
-- ---------------------------------------------------------------------------
server.route ("GET", "/users/", function (request, response)
    local path = request:get_path ()
    local id   = tonumber (path:match ("/users/(%d+)"))

    if id == nil then
        local message = "Bad request: expected /users/<integer id>"
        response:status     (400)
        response:header     ("Content-Type",   "text/plain; charset=utf-8")
        response:header     ("Content-Length",  #message)
        response:header     ("Connection",     "close")
        response:end_header ()
        response:body       (message)
        coroutine.yield() -- CORRECCIÓN: Faltaba ceder tras un error 400
        return
    end

    local row = database.query("SELECT name, email, score FROM users WHERE id = ?", {id})

    if row:advance() then
        local body = "name="   .. row:get_string (1)
                  .. " email=" .. row:get_string (2)
                  .. " score=" .. row:get_real   (3)

        response:status     (200)
        response:header     ("Content-Type",   "text/plain; charset=utf-8")
        response:header     ("Content-Length",  #body)
        response:header     ("Connection",     "close")
        response:end_header ()
        response:body       (body)
        coroutine.yield() -- CORRECCIÓN: Asegura el envío del 200 OK
    else
        local message = "User " .. id .. " not found"
        response:status     (404)
        response:header     ("Content-Type",   "text/plain; charset=utf-8")
        response:header     ("Content-Length",  #message)
        response:header     ("Connection",     "close")
        response:end_header ()
        response:body       (message)
        coroutine.yield() -- CORRECCIÓN: Asegura el envío del 404 Not Found
    end
end)

-- ---------------------------------------------------------------------------
-- POST /users
-- ---------------------------------------------------------------------------
server.route ("POST", "/users", function (request, response)
    local body  = request:get_body ()
    local name  = body:match ("name=([^&]+)")
    local email = body:match ("email=([^&]+)")
    local score = tonumber (body:match ("score=([^&]+)"))

    if name == nil or email == nil or score == nil then
        local message = "Bad request: expected body 'name=...&email=...&score=...'"
        response:status     (400)
        response:header     ("Content-Type",   "text/plain; charset=utf-8")
        response:header     ("Content-Length",  #message)
        response:header     ("Connection",     "close")
        response:end_header ()
        response:body       (message)
        coroutine.yield() -- CORRECCIÓN: Faltaba ceder tras error de parseo
        return
    end

    database.execute("INSERT INTO users (name, email, score) VALUES (?, ?, ?)", {name, email, score})

    local row     = database.query("SELECT id FROM users WHERE email = ?", {email})
    local message

    if row:advance() then
        message = "Created user with id=" .. row:get_integer(1)
    else
        message = "Insert succeeded but could not retrieve new id"
    end

    response:status     (201)
    response:header     ("Content-Type",   "text/plain; charset=utf-8")
    response:header     ("Content-Length",  #message)
    response:header     ("Connection",     "close")
    response:end_header ()
    response:body       (message)
    
    coroutine.yield() -- CORRECCIÓN: Faltaba ceder al final del proceso exitoso
end)

-- ---------------------------------------------------------------------------
-- DELETE /users/<id>
-- ---------------------------------------------------------------------------
server.route ("DELETE", "/users/", function (request, response)
    local path = request:get_path ()
    local id   = tonumber (path:match ("/users/(%d+)"))

    if id == nil then
        local message = "Bad request: expected /users/<integer id>"
        response:status     (400)
        response:header     ("Content-Type",   "text/plain; charset=utf-8")
        response:header     ("Content-Length",  #message)
        response:header     ("Connection",     "close")
        response:end_header ()
        response:body       (message)
        coroutine.yield() -- CORRECCIÓN: Faltaba ceder en este return prematuro
        return
    end

    database.execute("DELETE FROM users WHERE id = ?", {id})

    local message = "Deleted user " .. id

    response:status     (200)
    response:header     ("Content-Type",   "text/plain; charset=utf-8")
    response:header     ("Content-Length",  #message)
    response:header     ("Connection",     "close")
    response:end_header ()
    response:body       (message)
    
    coroutine.yield() -- CORRECCIÓN: Faltaba ceder tras borrar con éxito
end)