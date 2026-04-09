import express from 'express';
import cors from 'cors';
import bcrypt from 'bcrypt';

import dotenv from 'dotenv';
import db from './models/index.js';
import {serveSwagger, setupSwagger} from "./config/swagger.js";
import categoryRoutes from './routes/Category.route.js';
import userRoutes from './routes/User.route.js';
import recordRoutes from './routes/Record.route.js';
import summaryRoutes from './routes/Summary.route.js';


dotenv.config();

const app = express();
const frontURL = process.env.FRONTEND_URL;
console.log('listen from ', frontURL);
app.use(cors({
    origin: '*',
}));
app.use(express.json());

app.use('/docs', serveSwagger, setupSwagger);

// API Routes (prefixed with /api for ALB deployment)
app.use('/api/categories', categoryRoutes);
app.use('/api/records', recordRoutes);
app.use('/api/users', userRoutes);
app.use('/api/summary', summaryRoutes);

// Keep original routes for backwards compatibility
app.use('/categories', categoryRoutes);
app.use('/records', recordRoutes);
app.use('/users', userRoutes);
app.use('/summary', summaryRoutes);

// Health check endpoint for ALB
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
});

app.get('/api', (req, res) => {
    res.send('Expense Tracker API');
});

// Sync DB and seed if empty
try {
    await db.sequelize.sync();
    console.log('Database synced');

    // Auto-seed if no users exist
    const userCount = await db.User.count();
    if (userCount === 0) {
        console.log('No users found — seeding database...');

        const users = await Promise.all(
            ['alice', 'bob', 'charlie'].map(async (username, index) => {
                const hashedPassword = await bcrypt.hash(`pass${index + 1}`, 10);
                return db.User.create({
                    username,
                    email: `${username}@example.com`,
                    password: hashedPassword
                });
            })
        );

        const allCategories = [];
        for (const user of users) {
            const userCategories = await db.Category.bulkCreate([
                { name: 'Food', color: '#ff5722', userId: user.id },
                { name: 'Gas', color: '#2196f3', userId: user.id },
                { name: 'Services', color: '#4caf50', userId: user.id }
            ]);
            allCategories.push(...userCategories);
        }

        const currencies = ['USD', 'KHR'];
        const titles = [
            'Coffee', 'Lunch', 'Dinner', 'Breakfast', 'Snacks', 'Groceries',
            'Gas Refill', 'Car Wash', 'Parking', 'Taxi', 'Bus Fare', 'Uber',
            'Phone Bill', 'Internet', 'Electricity', 'Water Bill', 'Repair', 'Subscription',
            'Movie', 'Concert', 'Books', 'Gym', 'Healthcare', 'Shopping',
            'Insurance', 'Bank Fees', 'ATM Fee', 'Transfer Fee', 'Maintenance', 'Cleaning'
        ];

        const records = [];
        const currentDate = new Date();

        const monthsData = [];
        for (let monthOffset = 0; monthOffset < 3; monthOffset++) {
            const targetDate = new Date(currentDate.getFullYear(), currentDate.getMonth() - monthOffset, 1);
            const year = targetDate.getFullYear();
            const month = targetDate.getMonth();
            const daysInMonth = new Date(year, month + 1, 0).getDate();
            monthsData.push({ year, month, daysInMonth });
        }

        for (const user of users) {
            const userCategories = allCategories.filter(cat => cat.userId === user.id);
            for (const monthData of monthsData) {
                const recordsPerMonth = 30 + Math.floor(Math.random() * 10);
                for (let i = 0; i < recordsPerMonth; i++) {
                    const category = userCategories[Math.floor(Math.random() * userCategories.length)];
                    const currency = currencies[Math.floor(Math.random() * currencies.length)];
                    let amount;
                    if (currency === 'USD') {
                        if (category.name === 'Food') amount = parseFloat((Math.random() * 80 + 5).toFixed(2));
                        else if (category.name === 'Gas') amount = parseFloat((Math.random() * 120 + 30).toFixed(2));
                        else amount = parseFloat((Math.random() * 200 + 20).toFixed(2));
                    } else {
                        if (category.name === 'Food') amount = parseFloat((Math.random() * 320000 + 20000).toFixed(0));
                        else if (category.name === 'Gas') amount = parseFloat((Math.random() * 480000 + 120000).toFixed(0));
                        else amount = parseFloat((Math.random() * 800000 + 80000).toFixed(0));
                    }
                    const day = Math.floor(Math.random() * monthData.daysInMonth) + 1;
                    const date = new Date(monthData.year, monthData.month, day).toISOString().split('T')[0];
                    records.push({
                        title: titles[Math.floor(Math.random() * titles.length)],
                        date, currency, amount,
                        note: `Expense #${i + 1}`,
                        userId: user.id,
                        categoryId: category.id
                    });
                }
            }
        }

        await db.Record.bulkCreate(records);
        console.log(`Seeded: ${users.length} users, ${allCategories.length} categories, ${records.length} records`);
    }
} catch (err) {
    console.error('DB sync/seed failed:', err);
}
export default app;
