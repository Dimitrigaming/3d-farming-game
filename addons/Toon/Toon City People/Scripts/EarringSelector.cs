using System.Collections.Generic;
using UnityEngine;

namespace EarringSelector
{

    public class EarringSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_EARRINGS = 19
;
        [Range(0, MAXIMUM_NUMBER_EARRINGS - 1)]
        public int Earring;
        public GameObject[] Earrings = new GameObject[MAXIMUM_NUMBER_EARRINGS];


        void OnValidate()
        {
		ValidateObject(Earring, Earrings);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}
