package com.demo.taskapp

import com.demo.taskapp.data.TaskDto
import com.demo.taskapp.ui.AppUiState
import org.junit.Assert.*
import org.junit.Test

class TaskViewModelTest {
    @Test
    fun `initial state has no user logged in`() {
        val state = AppUiState()
        assertFalse(state.isLoggedIn)
        assertEquals("", state.userName)
        assertTrue(state.tasks.isEmpty())
        assertFalse(state.isLoading)
        assertNull(state.error)
    }

    @Test
    fun `TaskDto serialization defaults`() {
        val task = TaskDto(id = "1", title = "Test Task")
        assertEquals("pending", task.status)
        assertEquals(0, task.priority)
        assertNull(task.description)
    }

    @Test
    fun `state copy preserves other fields`() {
        val state = AppUiState(isLoggedIn = true, userName = "Alice", tasks = listOf(TaskDto("1", "T")))
        val updated = state.copy(isLoading = true)
        assertTrue(updated.isLoggedIn)
        assertEquals("Alice", updated.userName)
        assertEquals(1, updated.tasks.size)
        assertTrue(updated.isLoading)
    }
}
