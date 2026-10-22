import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Task } from './task.entity';

@Injectable()
export class TasksService {
  constructor(@InjectRepository(Task) private repo: Repository<Task>) {}

  async create(userId: string, title: string, description?: string, priority = 0, dueDate?: Date): Promise<Task> {
    const task = this.repo.create({ userId, title, description, priority, dueDate });
    return this.repo.save(task);
  }

  async findByUser(userId: string, limit = 25, offset = 0): Promise<[Task[], number]> {
    return this.repo.findAndCount({
      where: { userId },
      take: limit,
      skip: offset,
      order: { priority: 'DESC', createdAt: 'DESC' },
    });
  }

  async findOne(id: string, userId: string): Promise<Task> {
    const task = await this.repo.findOne({ where: { id, userId } });
    if (!task) throw new NotFoundException('Task not found');
    return task;
  }

  async update(id: string, userId: string, updates: Partial<Pick<Task, 'title' | 'description' | 'status' | 'priority' | 'dueDate'>>): Promise<Task> {
    const task = await this.findOne(id, userId);
    Object.assign(task, updates);
    return this.repo.save(task);
  }

  async remove(id: string, userId: string): Promise<void> {
    const task = await this.findOne(id, userId);
    await this.repo.remove(task);
  }
}
