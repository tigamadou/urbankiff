const path = require("path")

module.exports = {
    reactScriptsVersion: "react-scripts",
    style: {
        sass: {
            loaderOptions: {
                sassOptions: {
                    includePaths: ["node_modules", "src/assets"]
                }
            }
        },
        postcss: {
            plugins: [require("postcss-rtl")()]
        }
    },
    module: {
        rules: [
            {
                test: /\.mjs$/,
                include: /node_modules/,
                type: "javascript/auto"
            }
        ]
    },
    jest: {
        configure: {
            moduleNameMapper: {
                "^axios$": "<rootDir>/node_modules/axios/dist/node/axios.cjs",
                "^@src/(.*)$": "<rootDir>/src/$1",
                "^@assets/(.*)$": "<rootDir>/src/@core/assets/$1",
                "^@components/(.*)$": "<rootDir>/src/@core/components/$1",
                "^@layouts/(.*)$": "<rootDir>/src/@core/layouts/$1",
                "^@store/(.*)$": "<rootDir>/src/redux/$1",
                "^@styles/(.*)$": "<rootDir>/src/@core/scss/$1",
                "^@configs/(.*)$": "<rootDir>/src/configs/$1",
                "^@utils$": "<rootDir>/src/utility/Utils",
                "^@hooks/(.*)$": "<rootDir>/src/utility/hooks/$1",
                "^@i18n/(.*)$": "<rootDir>/src/i18n/locales/$1",
                "^@locales/(.*)$": "<rootDir>/src/i18n/locales/$1"
            }
        }
    },
    webpack: {
        alias: {
            "@src": path.resolve(__dirname, "src"),
            "@assets": path.resolve(__dirname, "src/@core/assets"),
            "@components": path.resolve(__dirname, "src/@core/components"),
            "@layouts": path.resolve(__dirname, "src/@core/layouts"),
            "@store": path.resolve(__dirname, "src/redux"),
            "@styles": path.resolve(__dirname, "src/@core/scss"),
            "@configs": path.resolve(__dirname, "src/configs"),
            "@utils": path.resolve(__dirname, "src/utility/Utils"),
            "@hooks": path.resolve(__dirname, "src/utility/hooks"),
            "@i18n": path.resolve(__dirname, "src/i18n/locales"),
            "@locales": path.resolve(__dirname, "src/i18n/locales")
        }
    }
}
