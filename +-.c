#include<stdio.h>
int main()
{
    int x,y;
    char op;
    printf("Enter the first number:");
    scanf("%d",&x);
   
    printf("Enter the second number:");
    scanf("%d",&y);

    printf("Arithmetic Operation:");
    scanf(" %c",&op);

    if(op == '+'){
        printf("The sum is:%d \n",x+y);
    } else if(op == '-') {
        printf("The sub is:%d \n",x-y);
    } else if(op == '*') {
        printf("The Multiply is:%d \n",x*y);
    }else if(op == '/') {
        printf("The division is:%d \n",x/y);

    }else {
        printf("ERROR \n");
    }

    return 0;
}