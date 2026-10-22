package com.demo.taskapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import com.demo.taskapp.ui.LoginScreen
import com.demo.taskapp.ui.TaskListScreen
import com.demo.taskapp.ui.TaskViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                val vm: TaskViewModel = viewModel()
                val state by vm.uiState.collectAsState()

                if (!state.isLoggedIn) {
                    LoginScreen(
                        isLoading = state.isLoading,
                        error = state.error,
                        onLogin = vm::login,
                        onRegister = vm::register,
                        onClearError = vm::clearError,
                    )
                } else {
                    TaskListScreen(
                        userName = state.userName,
                        tasks = state.tasks,
                        isLoading = state.isLoading,
                        onAddTask = vm::addTask,
                        onToggleStatus = vm::toggleTaskStatus,
                        onDeleteTask = vm::deleteTask,
                        onRefresh = vm::loadTasks,
                    )
                }
            }
        }
    }
}
