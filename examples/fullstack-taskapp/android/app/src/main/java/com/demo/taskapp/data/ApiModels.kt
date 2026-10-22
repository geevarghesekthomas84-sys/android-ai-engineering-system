package com.demo.taskapp.data

import kotlinx.serialization.Serializable

@Serializable
data class LoginRequest(val email: String, val password: String)

@Serializable
data class RegisterRequest(val email: String, val displayName: String, val password: String)

@Serializable
data class AuthResponse(val user: UserDto, val token: String)

@Serializable
data class UserDto(val id: String, val email: String, val displayName: String)

@Serializable
data class TaskDto(
    val id: String,
    val title: String,
    val description: String? = null,
    val status: String = "pending",
    val priority: Int = 0,
    val dueDate: String? = null,
)

@Serializable
data class CreateTaskRequest(val title: String, val description: String? = null, val priority: Int = 0)

@Serializable
data class UpdateTaskRequest(
    val title: String? = null,
    val description: String? = null,
    val status: String? = null,
    val priority: Int? = null,
)

@Serializable
data class TaskListResponse(val data: List<TaskDto>, val pagination: PaginationDto)

@Serializable
data class PaginationDto(val total: Int, val limit: Int, val offset: Int)
