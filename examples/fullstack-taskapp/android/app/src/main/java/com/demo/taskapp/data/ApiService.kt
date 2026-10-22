package com.demo.taskapp.data

import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.http.*

interface ApiService {
    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): AuthResponse

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    @GET("tasks")
    suspend fun getTasks(@Header("Authorization") auth: String): TaskListResponse

    @POST("tasks")
    suspend fun createTask(@Header("Authorization") auth: String, @Body request: CreateTaskRequest): TaskDto

    @PATCH("tasks/{id}")
    suspend fun updateTask(@Header("Authorization") auth: String, @Path("id") id: String, @Body request: UpdateTaskRequest): TaskDto

    @DELETE("tasks/{id}")
    suspend fun deleteTask(@Header("Authorization") auth: String, @Path("id") id: String)

    companion object {
        fun create(baseUrl: String = "http://10.0.2.2:3000/"): ApiService {
            val json = Json { ignoreUnknownKeys = true }
            val client = OkHttpClient.Builder()
                .addInterceptor(HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY })
                .build()
            return Retrofit.Builder()
                .baseUrl(baseUrl)
                .client(client)
                .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
                .build()
                .create(ApiService::class.java)
        }
    }
}
