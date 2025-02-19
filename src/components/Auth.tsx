import React from 'react';
import { User } from 'lucide-react';

export function Auth() {
  return (
    <div className="flex items-center gap-2 px-4 py-2 text-gray-600">
      <User className="w-4 h-4" />
      <span>Guest User</span>
    </div>
  );
}