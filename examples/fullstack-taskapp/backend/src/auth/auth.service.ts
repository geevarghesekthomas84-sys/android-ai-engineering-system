import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
  ) {}

  async register(email: string, displayName: string, password: string) {
    const user = await this.usersService.create(email, displayName, password);
    const token = await this.jwtService.signAsync({ sub: user.id, email: user.email, role: user.role });
    return { user: { id: user.id, email: user.email, displayName: user.displayName }, token };
  }

  async login(email: string, password: string) {
    const user = await this.usersService.findByEmail(email);
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    const token = await this.jwtService.signAsync({ sub: user.id, email: user.email, role: user.role });
    return { user: { id: user.id, email: user.email, displayName: user.displayName }, token };
  }
}
