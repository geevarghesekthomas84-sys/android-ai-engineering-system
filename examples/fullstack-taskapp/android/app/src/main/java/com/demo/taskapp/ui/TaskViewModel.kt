package com.demo.taskapp.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.demo.taskapp.data.TaskDto
import com.demo.taskapp.data.TaskRepository
import com.demo.taskapp.data.UpdateTaskRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AppUiState(
    val isLoggedIn: Boolean = false,
    val userName: String = "",
    val tasks: List<TaskDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

class TaskViewModel(private val repo: TaskRepository = TaskRepository()) : ViewModel() {
    private val _uiState = MutableStateFlow(AppUiState())
    val uiState: StateFlow<AppUiState> = _uiState.asStateFlow()

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            repo.login(email, password)
                .onSuccess { auth ->
                    _uiState.value = _uiState.value.copy(
                        isLoggedIn = true,
                        userName = auth.user.displayName,
                        isLoading = false,
                    )
                    loadTasks()
                }
                .onFailure { e ->
                    _uiState.value = _uiState.value.copy(isLoading = false, error = e.message)
                }
        }
    }

    fun register(email: String, displayName: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            repo.register(email, displayName, password)
                .onSuccess { auth ->
                    _uiState.value = _uiState.value.copy(
                        isLoggedIn = true,
                        userName = auth.user.displayName,
                        isLoading = false,
                    )
                    loadTasks()
                }
                .onFailure { e ->
                    _uiState.value = _uiState.value.copy(isLoading = false, error = e.message)
                }
        }
    }

    fun loadTasks() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            repo.getTasks()
                .onSuccess { tasks ->
                    _uiState.value = _uiState.value.copy(tasks = tasks, isLoading = false)
                }
                .onFailure { e ->
                    _uiState.value = _uiState.value.copy(isLoading = false, error = e.message)
                }
        }
    }

    fun addTask(title: String, description: String?) {
        viewModelScope.launch {
            repo.createTask(title, description)
                .onSuccess { loadTasks() }
                .onFailure { e ->
                    _uiState.value = _uiState.value.copy(error = e.message)
                }
        }
    }

    fun toggleTaskStatus(task: TaskDto) {
        viewModelScope.launch {
            val newStatus = if (task.status == "completed") "pending" else "completed"
            repo.updateTask(task.id, UpdateTaskRequest(status = newStatus))
                .onSuccess { loadTasks() }
        }
    }

    fun deleteTask(id: String) {
        viewModelScope.launch {
            repo.deleteTask(id)
                .onSuccess { loadTasks() }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}
