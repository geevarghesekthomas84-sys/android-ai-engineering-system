package com.demo.taskapp.data

class TaskRepository(private val api: ApiService = ApiService.create()) {
    private var token: String? = null

    private fun authHeader(): String = "Bearer ${token.orEmpty()}"

    suspend fun login(email: String, password: String): Result<AuthResponse> = runCatching {
        val response = api.login(LoginRequest(email, password))
        token = response.token
        response
    }

    suspend fun register(email: String, displayName: String, password: String): Result<AuthResponse> = runCatching {
        val response = api.register(RegisterRequest(email, displayName, password))
        token = response.token
        response
    }

    suspend fun getTasks(): Result<List<TaskDto>> = runCatching {
        api.getTasks(authHeader()).data
    }

    suspend fun createTask(title: String, description: String? = null, priority: Int = 0): Result<TaskDto> = runCatching {
        api.createTask(authHeader(), CreateTaskRequest(title, description, priority))
    }

    suspend fun updateTask(id: String, updates: UpdateTaskRequest): Result<TaskDto> = runCatching {
        api.updateTask(authHeader(), id, updates)
    }

    suspend fun deleteTask(id: String): Result<Unit> = runCatching {
        api.deleteTask(authHeader(), id)
    }

    val isLoggedIn: Boolean get() = token != null
}
